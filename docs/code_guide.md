# Ghi chú mã nguồn và vai trò các file

Các script `.gd` dùng `##` để mô tả lớp, hàm và thuộc tính quan trọng, `#` để giải thích bước xử lý bên trong. Scene/resource/cấu hình dùng `;`. JSON không hỗ trợ comment nên cấu trúc được ghi riêng trong [hướng dẫn dữ liệu truyện](../data/story/README.md).

## Luồng hoạt động

`project.godot` mở splash → menu chính → chapter đầu hoặc chapter trong save. `GameManager` và `GlobalMenu` là autoload, tồn tại khi chuyển màn hình.

Các scene chương kế thừa `chapter_base.tscn`. Script của từng chương kế thừa `StoryChapter`, rồi đến `ChapterBase`. `ChapterBase` đọc dữ liệu, dựng chat và chạy sự kiện; `StoryChapter` bổ sung cờ truyện, manh mối, điều kiện, mốc quay lại và kết thúc.

Khi gặp câu đố: `ChapterBase.start_minigame()` tạo instance → gọi `configure()` → thêm vào cây để chạy `_ready()` → gọi `restore_state()` → chờ `finished(result)`. Chapter ghi kết quả và dọn instance. Khi Continue, lịch sử được dựng lại nhưng sự kiện gameplay đã xong không chạy lại.

## Mã nguồn

| File | Vai trò và chỗ chỉnh quan trọng |
| --- | --- |
| [game_manager.gd](../autoload/game_manager.gd) | Chuyển màn hình, chọn chương tiếp theo, ghi/đọc save, lưu và tải mốc. `save_game()` chặn scene cũ ghi đè tiến trình mới. |
| [chapter_base.gd](../scenes/chapters/base/chapter_base.gd) | Bộ đọc và UI chung. `load_story()` nạp JSON; `show_current_line()` hiển thị; `advance_dialogue()` đọc tiếp; `_process_json_event()` chạy hiệu ứng/câu đố; `get_progress()` tạo snapshot. |
| [story_chapter.gd](../scenes/chapters/base/story_chapter.gd) | Luật chiến dịch. `matches()` xét cờ; `apply_effects()` cập nhật cờ/manh mối; `go_to_scene()` đi tới ID cảnh; `complete_chapter()` ghi kết thúc đã đọc xong. |
| [chapter1.gd](../scenes/chapters/chapter_01/chapter1.gd) | Điểm mở rộng Chương 1; hiện dùng toàn bộ xử lý của `StoryChapter`. |
| [chapter2.gd](../scenes/chapters/chapter_02/chapter2.gd) | Điểm mở rộng Chương 2; tuyến truyện được khai báo trong JSON. |
| [chapter3.gd](../scenes/chapters/chapter_03/chapter3.gd) | Điểm mở rộng Chương 3; cờ xác minh và manh mối đi qua `StoryChapter`. |
| [chapter4.gd](../scenes/chapters/chapter_04/chapter4.gd) | Điểm mở rộng Chương 4, dùng dữ liệu các việc chuẩn bị và mốc đầu chương. |
| [chapter5.gd](../scenes/chapters/chapter_05/chapter5.gd) | Điểm mở rộng Chương 5, dùng dữ liệu lựa chọn và các kết thúc. |
| [chat_message.gd](../scenes/ui/chat/chat_message.gd) | Bố cục bong bóng, avatar, lời dẫn và ảnh. Chỉnh hằng màu/kích thước hoặc các hàm `setup_*` để đổi giao diện chat. |
| [story_notebook.gd](../scenes/ui/story_notebook.gd) | Sổ tay tạo bằng code. `open()` dựng dữ liệu mới nhất; `_ask_restore()` xác nhận trước khi tải mốc. |
| [story_puzzle.gd](../scenes/minigames/story_puzzle.gd) | Câu đố chọn/xếp/nối. `choose()` kiểm đáp án, `assist()` hỗ trợ, `finish()` phát kết quả một lần; cặp hàm save/restore giữ ván dở. |
| [global_menu.gd](../scenes/global_menu/global_menu.gd) | Nút bánh răng, Esc và chu kỳ Auto tắt/thường/x2. Gửi thời gian mỗi frame cho chapter để đọc tự động. |
| [main_menu.gd](../scenes/main_menu/main_menu.gd) | Chơi mới, Continue, mở cài đặt, thoát và con trỏ hover. |
| [settings.gd](../scenes/settings/settings.gd) | Lưu âm lượng/toàn màn hình trong `user://settings.cfg`; lớp phủ chạy khi pause và trả focus khi đóng. |
| [ui_sound_manager.gd](../scenes/settings/ui_sound_manager.gd) | Nối hover/click cho các nút đang có dưới node cha tại `_ready()`, phát trên bus SFX. |
| [splash.gd](../scenes/splash/splash.gd) | Hiện logo rồi chuyển menu; hai hằng thời lượng tính bằng giây. |
| [credit_entry.gd](../scenes/credits/credit_entry.gd) | Resource chữ/ảnh của một mục cảm ơn, chỉnh trong Inspector. |
| [credits.gd](../scenes/credits/credits.gd) | Dựng danh sách chữ/ảnh, cuộn theo tốc độ cấu hình rồi fade về menu. |
| [validate_story.py](../tests/validate_story.py) | Kiểm tra liên kết cảnh, asset, đáp án và mốc bằng Python. Không mô phỏng điều kiện của một lượt chơi. |
| [chapter_regression.gd](../tests/chapter_regression.gd) | Kiểm thử bộ đọc cũ, save/Continue, fade, hook và giao thức minigame bằng fixture. |
| [story_regression.gd](../tests/story_regression.gd) | Chạy các tuyến đại diện, bốn kết thúc, tải mốc, trợ giúp và tiếp tục câu đố. |
| [global_menu_regression.gd](../tests/global_menu_regression.gd) | Kiểm tra Auto, Esc, click, thứ tự lớp phủ, pause và focus khi đang chơi minigame. |

## Scene, resource và cấu hình

| File/nhóm file | Vai trò |
| --- | --- |
| [project.godot](../project.godot) | Scene khởi động, autoload, viewport, bus và renderer của toàn project. |
| [export_presets.cfg](../export_presets.cfg) | Cấu hình xuất Android: đường dẫn APK, bộ lọc, CPU, package và tùy chọn nền tảng. |
| [default_bus_layout.tres](../default_bus_layout.tres) | Hai bus Music/SFX gửi về Master; tên bus được script dùng để điều chỉnh âm lượng. |
| [main_theme.tres](../themes/main_theme.tres) | Theme tối giản, hiện chỉ có thuộc tính cỡ chữ mặc định. |
| [settings_slider_theme.tres](../themes/settings_slider_theme.tres) | Style rãnh/phần kéo và texture núm thanh âm lượng. |
| [chapter_base.tscn](../scenes/chapters/base/chapter_base.tscn) | UI kế thừa: nền, đồng hồ, chat, hướng dẫn, lựa chọn, player nhạc và container minigame. |
| `scenes/chapters/chapter_01/chapter1.tscn` … `chapter_05/chapter5.tscn` | Mỗi file gắn script chương tương ứng và cấu hình ID, tên, `story_path`, avatar, người nói chính, nhạc. |
| [story_puzzle.tscn](../scenes/minigames/story_puzzle.tscn) | Root minigame; các control con được script dựng từ cấu hình câu đố. |
| [chat_message.tscn](../scenes/ui/chat/chat_message.tscn) | Root của một mục chat; hình thức cụ thể được tạo bằng `setup_*`. |
| [main_menu.tscn](../scenes/main_menu/main_menu.tscn) | Bố cục menu, video, logo, các nút và âm thanh. |
| [GlobalMenu.tscn](../scenes/global_menu/GlobalMenu.tscn) | Menu autoload trên CanvasLayer 100, phía trên chapter. |
| [settings.tscn](../scenes/settings/settings.tscn) | Cài đặt trên CanvasLayer 101, phía trên nút menu và minigame. |
| [splash.tscn](../scenes/splash/splash.tscn) | Bố cục logo lúc khởi động. |
| [credits.tscn](../scenes/credits/credits.tscn) | Danh sách CreditEntry, vùng cuộn, lớp fade và nhạc kết thúc. |

Godot có thể bỏ comment trong `.tscn`, `.tres` hoặc cấu hình khi lưu lại bằng editor. Bảng này giữ mô tả để tra cứu lâu dài.

## Dữ liệu, tài nguyên và tài liệu

| File/nhóm file | Vai trò |
| --- | --- |
| `data/story/chapter_01.json` … `chapter_05.json` | Nội dung hiện hành; xem [trường dữ liệu và cách dùng](../data/story/README.md). |
| `tests/fixtures/legacy_chapter_01/*.json` | Nội dung cũ phục vụ hồi quy; [README của fixture](../tests/fixtures/legacy_chapter_01/README.md) giải thích từng file. |
| `assets/avatars/` | Avatar và hình nhân vật; script/JSON tham chiếu theo đường dẫn. |
| `assets/chapter1/`, các ảnh ở `assets/` | Tranh bối cảnh và vật thể dùng trong truyện. |
| `assets/backgrounds/` | Ảnh/video menu, logo, font và các thư mục UI/âm thanh. |
| `assets/backgrounds/ui/clock.svg` | Biểu tượng đồng hồ của header chapter. |
| `assets/backgrounds/ui/settings/slider_grabber*.svg` | Núm thanh âm lượng ở trạng thái thường, sáng và vô hiệu hóa. |
| `assets/backgrounds/audio/`, `assets/sound_effect/` | Nhạc nền và hiệu ứng; trường `sfx` của dòng truyện tìm MP3 theo tên trong `assets/sound_effect/`. |
| `bg_godot.webm`, `scenes/main_menu/bg_new.mp4` | Các file video trong project; video thực sự được dùng phụ thuộc tham chiếu của scene. |
| `*.uid`, `*.import` | Định danh và thông số nhập tài nguyên do Godot quản lý; không chèn ghi chú vào các file này. |
| `.godot/`, `tests/.tmp/` | Cache/import và dữ liệu kiểm thử sinh ra; không phải mã nguồn để sửa gameplay. |
| [chapters.md](chapters.md) | Chi tiết kiến trúc ChapterBase, save và giao thức minigame; có ví dụ triển khai bộ đọc cũ. |
| [story_campaign.md](story_campaign.md) | Cách chơi bản năm chương, điều kiện kết thúc, tổ chức dữ liệu và kiểm thử chiến dịch. |

## Kiểm tra sau khi chỉnh sửa

Chạy trong thư mục project, thay `Godot` bằng đường dẫn executable đang cài:

```powershell
python tests/validate_story.py
Godot --headless --editor --import --quit --path .
Godot --headless --path . --script res://tests/chapter_regression.gd
Godot --headless --path . --script res://tests/story_regression.gd
Godot --headless --path . --script res://tests/global_menu_regression.gd
```

Các bộ kiểm thử GDScript đặt `GameManager.save_path` trong `tests/.tmp/` trước khi chơi mới, để tách tiến trình kiểm thử khỏi save người chơi.
