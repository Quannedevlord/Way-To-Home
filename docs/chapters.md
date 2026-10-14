# Chapter dùng chung trong Way To Home

Project dùng Godot 4.7, đã chạy kiểm tra bằng Godot 4.7.2. Không thêm Autoload hoặc plugin.

## Các file và trách nhiệm

| Thay đổi | File | Trách nhiệm |
| --- | --- | --- |
| Tạo | `scenes/chapters/base/chapter_base.gd`, `.gd.uid`, `chapter_base.tscn` | `ChapterBase`: JSON, thoại/lời dẫn/ảnh/địa điểm, lựa chọn, chuyển file, âm thanh/nền/fade, input, snapshot/restore, sự kiện và vòng đời minigame. Scene giữ các node và tham chiếu Inspector gốc, thêm `MinigameContainer`. |
| Di chuyển | `scenes/chapters/chapter_01/chat_message.gd`, `.gd.uid`, `.tscn` → `scenes/ui/chat/` | UI bubble dùng chung; giữ UID và toàn bộ cách vẽ/animation. Cập nhật preload và đường dẫn script trong scene. |
| Sửa | `scenes/chapters/chapter_01/chapter1.gd`, `.tscn` | Script kế thừa `ChapterBase`; inherited scene chỉ cấu hình Chapter 1, avatar, người nói lựa chọn, nhân vật căn phải và nhạc gốc. |
| Sửa | `scenes/chapters/chapter_02/chapter2.gd`, `.tscn` | Kế thừa cùng nền, gọi `super._ready()`. Khi `story_path` trống, báo hoàn thành ở deferred call và tự chuyển chapter/credits như scene tạm trước đây. Nếu đã cấu hình story thì chạy nền bình thường. |
| Sửa | `autoload/game_manager.gd` | Nhận signal hoàn thành, điều phối scene/chapter, ghi/đọc save. Không chứa gameplay chapter. |
| Sửa | `data/chap1_story/main_story.json` | Chỉ thêm `use_as_background: false` cho ảnh vòng tay; giữ nguyên nội dung/thứ tự/asset/sự kiện/lựa chọn. Các JSON nhánh không đổi. |
| Tạo | `tests/chapter_regression.gd`, `.gd.uid`, `tests/.gitignore` | Kiểm tra hồi quy headless; tạo dữ liệu và đối tượng giả trong `tests/.tmp/`, không thêm minigame chơi được. |
| Tạo | `docs/chapters.md` | Hướng dẫn này. |

Các tên hàm và biến gốc được giữ khi có thể. `STORY_PATH` trở thành `story_path` trong Inspector; `current_story_path` theo dõi file đang đọc. `change_scene()` trả `bool` để chỉ ghi tiến trình chapter mới khi chuyển scene thành công. `play_sfx(stream)` thực sự gán stream và bus SFX, thay cho hàm cũ tạo player rỗng. Các sự kiện có hàng đợi tuần tự; thao tác tiếp tục tạm khóa trong lúc xử lý để không chồng fade hoặc mở minigame sai dòng.

## Save và tương thích

Save vẫn là `user://savegame.save`, định dạng `ConfigFile`. Ngoài các index cũ, save chứa:

- `current_scene` để chọn chapter trước khi khôi phục.
- `chapter_id`, `current_story_path` để chọn đúng nội dung của chapter.
- `selected_choice_index`, `inline_choice_resolved`, `has_dialogue_override`, `dialogue_override` để khôi phục cả lựa chọn theo scene và lựa chọn nội tuyến có thoại riêng.
- `chat_history` để giữ thứ tự thoại, ảnh, lời lựa chọn và khôi phục nền/nhạc/địa điểm từ những file trước.
- `fade_alpha` để khôi phục trạng thái cuối của fade, không phát lại animation khi dựng lịch sử.
- `minigame_state` lưu kết quả theo ID; `pending_minigame` lưu sự kiện và trạng thái minigame đang chơi.
- `chapter_state` dành cho trạng thái đặc thù của chapter.

`next_file` được giải tương đối theo **thư mục file truyện hiện tại**, giữ cả thư mục con và `../`. Đường dẫn `res://` đầy đủ vẫn được chấp nhận. Chuyển file luôn đặt lại episode/scene/dialogue/lựa chọn; lịch sử chat tiếp tục như cũ.

Save cũ thiếu `current_story_path` dùng `story_path` trong Inspector, với index được giới hạn trong dữ liệu hiện tại. Save cũ không ghi file nhánh nên không thể suy ra chính xác nhánh đã chọn; mặc định trở về file đầu chương. Nếu file đã lưu bị gỡ, thử lại file đầu chương và reset tiến trình của chương. Không đoán nhánh bằng index.

`GameManager.save_game()` lấy snapshot trực tiếp từ chapter đang hoạt động và giữ các trường đã lưu của cùng scene. Chuyển chapter xóa section progress của scene trước rồi tạo index mới. `save_progress()` kiểm tra chủ sở hữu scene và bỏ qua chapter đã hoàn thành, tránh callback từ chapter cũ ghi đè save chapter mới. Về menu giữ save chapter; credits giữ `completed = true`. Biến `GameManager.save_path` chỉ được bộ kiểm thử đổi sang file riêng.

## Tạo Chapter 3

1. Trong Godot chọn **Scene → New Inherited Scene**, chọn `res://scenes/chapters/base/chapter_base.tscn`.
2. Đặt root là `Chapter3`, lưu `res://scenes/chapters/chapter_03/chapter3.tscn`. Giữ quy ước thư mục `chapter_XX` và tên file scene bắt đầu bằng `chapter` để GameManager tự tìm chương tiếp theo. Mỗi thư mục chapter nên có một entry scene.
3. Gắn script `chapter3.gd` có `extends ChapterBase`. Không sao chép logic thoại/UI của Chapter 1.
4. Trên root, cấu hình Inspector: `chapter_id = "chapter_03"`, `chapter_name`, `story_path`, `avatar_paths`, `protagonist_speakers`, `choice_speaker`; chọn `default_background` và `default_music` nếu cần. Các tham chiếu `chat_feed`, `scroll_container`, `location_label`, `choice_container`, `continue_hint` đã được kế thừa.
5. Thêm node/UI đặc thù vào inherited scene. Nếu override `_ready()`, gọi `super._ready()`. Nếu override `_input()` hoặc `_exit_tree()`, gọi lớp cha khi cần để giữ tiếp tục thoại và dọn coroutine.
6. Sự kiện riêng dùng `_handle_chapter_event(event: Dictionary) -> bool`. Trả `true` nếu chapter đã xử lý, `false` nếu không nhận diện; hàm có thể `await` animation hoặc kết quả. Hook này không chạy khi dựng lại lịch sử. Dùng `get_chapter_state() -> Dictionary` và `restore_chapter_state(state: Dictionary)` để lưu/khôi phục hiệu ứng gameplay riêng.
7. Khi logic riêng kết thúc chương, gọi `complete_chapter()`, không tự tăng chapter hay ghi save chapter tiếp theo.

JSON dạng mảng hiện có và dạng `{"episodes": [{"scenes": [...]}]}` đều được hỗ trợ. Đặt `use_as_background: false` trên dòng có ảnh chỉ dùng trong chat. Nếu bỏ trường này, ảnh tiếp tục đổi background như hành vi cũ.

## Tích hợp minigame riêng

Tạo scene minigame độc lập, root thường là Control đặt Full Rect. Minigame phải khai báo `signal finished(result: Dictionary)` và phát kết quả khi hoàn tất, ví dụ `finished.emit({"outcome": "win", "score": score})`. ChapterBase nhận signal, lưu kết quả, đóng container và `queue_free()` instance. Minigame nên để ChapterBase dọn node sau khi phát kết quả.

Khai báo event trên dòng JSON tại điểm cần mở minigame (các đường dẫn dưới đây là ví dụ cấu hình cho scene/nội dung bạn tự tạo, không được thêm vào truyện hiện tại):

```json
{
  "type": "narration",
  "text": "Nội dung của chapter do bạn viết",
  "event": {
    "type": "minigame",
    "id": "chapter_03_gate",
    "scene": "res://scenes/minigames/gate.tscn",
    "branches": {
      "win": {"next_file": "branches/win.json"},
      "lose": {"next_file": "branches/lose.json"}
    }
  }
}
```

`branches` đối chiếu `result.outcome`. Giá trị có thể là tên file trực tiếp, object `next_file`, hoặc object `next` (index thoại trong file đang đọc). Nếu không cấu hình nhánh tương ứng, đóng minigame rồi cho người chơi tiếp tục dòng kế tiếp bằng thao tác bình thường. Dùng ID duy nhất, ổn định; nếu không có ID, nền tạo ID từ vị trí và sự kiện.

Khi hoạt động, `MinigameContainer` chặn click xuyên xuống chat; `_input()` của nền không tiến thoại và gợi ý Continue bị ẩn. Khi dựng lịch sử, nền không chạy event minigame hoặc hook sự kiện riêng. Minigame đã có `completed` không mở lại, kể cả Continue ngay tại dòng chứa event. Minigame chưa hoàn thành được mở sau khi dựng lịch sử.

Để tiếp tục một ván đang chơi, minigame có thể triển khai `get_save_state() -> Dictionary` và `restore_state(state: Dictionary) -> void`. State chỉ chứa dữ liệu có thể lưu, không chứa Node, Callable hoặc Resource runtime. `restore_state()` được gọi sau khi instance vào tree; minigame không nên tự chạy ván mới trong `_ready()` trước khi có cơ hội khôi phục. Nếu không triển khai hai hàm này, ván chưa hoàn thành sẽ bắt đầu lại khi Continue. Kết quả completed vẫn được giữ.

Chapter có thể dùng `start_minigame(packed_scene, event_id, event_config)` trong hook riêng, rồi `await minigame_completed`; xử lý kết quả tại chapter. Với event JSON chuẩn, phần chờ kết quả và chọn nhánh đã do nền xử lý. Không cần sửa nền khi thêm một scene minigame mới.

## Kiểm chứng

Chạy từ thư mục project, dùng tên/path executable Godot phù hợp máy:

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --editor --import
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/chapter_regression.gd
```

Bộ kiểm thử dùng `tests/.tmp/savegame.save`, không đọc/ghi save thật. Nó kiểm tra scene kế thừa và Inspector, chơi mới, lựa chọn, cả hai nhánh, Continue main story và từng dòng trong các file nhánh, nền/nhạc xuyên file, fade, lưu lúc thoát, save cũ, chống scene cũ ghi đè, chuyển Chapter 2/credits, minigame/state/kết quả/không chạy lại và JSON dạng episodes với choices.

Kết quả thực tế trên Godot 4.7.2: import thành công, **113 checks, 0 failures**, tiến trình kiểm thử thoát với mã 0, không có lỗi script/resource trong log cuối. `git diff --check` cũng đạt.

Headless kiểm tra node/resource, tiến trình và trạng thái hiệu ứng; chưa xác nhận bằng mắt cách bố trí trên cửa sổ thật, chất lượng chuyển fade, nghe nhạc/SFX, click chuột thật, thao tác settings hoặc đóng cửa sổ bằng nút X. Tương đương logic lưu khi đóng cửa sổ được kiểm tra bằng `GameManager.save_game()`; chưa chạy thử chu kỳ đóng/mở ứng dụng thật qua GUI.

Kiểm tra trong editor:

1. F5 → chơi mới. Kiểm tra bubble/ảnh/avatar và nghe tiếng chuông, hiệu ứng đổi nền hành lang/phòng ngủ/giấc mơ, nhạc gốc và nhạc giấc mơ. Ảnh vòng tay chỉ nằm trong feed.
2. Ở cuối main story, thoát bằng nút X rồi chạy lại → Continue phải hiện lại hai lựa chọn.
3. Chọn từng nhánh (mỗi nhánh một lượt chơi). Trong `dy.json`, `tc.json`, `endbranch.json`, thoát rồi chạy lại → Continue giữ đúng dòng, lịch sử/lời lựa chọn và nền/nhạc giấc mơ.
4. Đọc hết endbranch → Chapter 2 tạm tự bỏ qua → credits; về menu không có Continue của lượt đã hoàn tất.
5. Mở inherited scene Chapter 1/2, xác nhận không có node/resource thiếu. Khi thêm Chapter 3, dùng F6 để chạy trực tiếp cấu hình của chapter; scene không có story mặc định không tự tạo nội dung.
6. Khi có minigame thật: thử kết thúc thắng/thua, thoát giữa ván rồi Continue, Continue tại dòng minigame vừa xong và kiểm tra click không xuyên xuống chat.
