# Bản truyện 5 chương

Triển khai theo `Way_To_Home_Kich_ban_5_chapter.docx`: 54 cảnh có ID, 451 dòng hội thoại/lời dẫn/tương tác, hai tuyến riêng ở chương 2 và chương 3, phần chuẩn bị có thể sửa ở chương 4 và bốn kết thúc. Nội dung đã chuyển thành JSON chơi được; chỉ dẫn dành cho người viết trong tài liệu không đưa nguyên văn vào hội thoại.

## Chạy thử

Mở `project.godot`, chạy F5 và chọn **Chơi mới** để bắt đầu kịch bản mới. Click hoặc Enter để đọc tiếp; chọn các nút khi có lựa chọn. Câu đố dùng các thẻ lớn, hỗ trợ bàn phím; bản đồ còn hỗ trợ kéo chuột/chạm qua các điểm. Sau lần thử đầu có nút trợ giúp. Không có giới hạn thời gian hoặc điểm phạt ảnh hưởng kết thúc.

Nút **Auto** nằm sát bên trái bánh răng ở góc trên phải. Bấm lần lượt **Auto: Tắt → Auto → Auto x2 → Auto: Tắt**. Thời gian đọc mỗi dòng tăng theo độ dài chữ (tối thiểu 2 giây); x2 giảm thời gian chờ còn một nửa. Auto chờ lựa chọn, minigame, sự kiện, cài đặt và sổ tay; tiếp tục khi người chơi xử lý xong. Có thể click hoặc Enter để đọc tiếp trong lúc bật Auto, dòng mới vẫn có đủ thời gian chờ. Chế độ được giữ khi chuyển chương và tắt khi về menu chính; không tăng tốc âm thanh hay minigame.

Trong lúc chơi, bấm bánh răng hoặc **Esc** để mở cài đặt trên minigame. Bấm **Esc** lần nữa hoặc nút X để đóng và tiếp tục đúng tiến độ. Lớp cài đặt tạm dừng game, dùng CanvasLayer 101 phía trên nút GlobalMenu/Auto (100) và các lớp của chapter. Kiểm tra riêng bằng `res://tests/global_menu_regression.gd`: 59 kiểm tra đạt, gồm Auto thường/x2, click chuột, Esc, tạm dừng và lưu/tiếp tục câu đố.

Nút **Sổ tay của Kiên** hiển thị các ghi chú, kèm dòng **Thông tin từ** giải thích Kiên đã tìm thấy ngoài đời, nghe gia đình xác nhận hay chỉ nghe Vy kể trong mơ. Cách giải thích nguồn này áp dụng cả với ghi chú đã lưu từ trước. Đến chương 4, sổ có thêm ba việc chuẩn bị với trạng thái **Đã làm xong / Chưa làm xong**. Phần **Chơi lại từ đoạn đã lưu** cho phép quay lại phần chuẩn bị ở Chương 4 hoặc chọn lại kết thúc ở Chương 5; sau credits có thể mở lại từ menu chính. Hộp xác nhận nêu rõ phần đã chơi sau đoạn được chọn sẽ cần làm lại. Việc quay lại phục hồi cả vị trí, cờ, manh mối và trạng thái câu đố của mốc đó.

## Các kết thúc

| Kết thúc | Cách mở |
| --- | --- |
| E1 · Nhà vẫn chờ | Hoàn thành xác minh ký ức, lời chào của Vy và thử đường về của Kiên; sau đó chủ động chọn khép lại con đường. |
| E2 · Lời chào bên cửa sổ | Chọn đưa Vy đến cửa và tạm biệt. Luôn mở, kể cả khi đã đủ điều kiện E1. |
| E3 · Người trở về một mình | Chọn tự trở về. Không bị tự gán vì lựa chọn ở chương 1 hoặc giải đố sai. |
| E4 · Buổi chiều không tắt | Chọn ở lại, nghe Vy nói rõ hậu quả rồi xác nhận **Ở lại**. Có thể đổi ý trước xác nhận. |

Chỉ đi tuyến Thư không tự hoàn thành xác minh: cần hỏi và nghe lời nhắn ở chương 3, hoặc đối chiếu ở chương 4. Viết thay Vy không hoàn thành lời chào; có thể quay lại để Vy tự viết. Dùng trợ giúp câu đố vẫn nhận cùng kết quả truyện. Lựa chọn E1 khi khóa hiện rõ việc còn thiếu.

## Tổ chức dữ liệu

- `data/story/chapter_01.json` đến `chapter_05.json`: nội dung đang dùng. Sửa trực tiếp những file này; game không cần file DOCX hay script chuyển đổi để chạy.
- `StoryChapter` kế thừa `ChapterBase`: thêm điều kiện `when`, tác động `set`/`clue`, đích cảnh `go`, điều kiện mở `requires`, xác nhận `confirm` và mốc `checkpoint`. ID cảnh ổn định, không nhảy nhánh bằng số dòng.
- `scenes/minigames/story_puzzle.tscn`: dùng chung cho 11 tương tác tìm/chọn chi tiết, nối đường, xếp thời gian và thử điểm neo. Có `configure`, `get_save_state`, `restore_state` và signal hoàn tất một lần.
- `GameManager`: section `campaign` trong save giữ trạng thái xuyên chương và các snapshot; section `collection` giữ kết thúc đã đọc xong. Chơi mới xóa tiến trình và mốc, giữ bộ sưu tập kết thúc.
- Thư mục kịch bản cũ đã được gỡ khỏi `data/`. Dữ liệu phục vụ kiểm thử bộ đọc cũ nằm riêng trong `tests/fixtures/legacy_chapter_01/`. Save trỏ tới file truyện đã gỡ sẽ mở lại đầu chương hiện hành, không giữ vị trí/lịch sử nhánh cũ. Save rất cũ không ghi tên file dùng nội dung đầu chương mới và giới hạn lại index; không thể suy ra nhánh hoặc thái độ cũ.

Các cờ chính: `promise_vy`, `route2`, `heard_anchor_hint`, `thu_informed`, `route3`, `memory_verified`, `farewell_ready`, `anchor_ready`, `ending_id`. Các cờ chuẩn bị chỉ được đặt sau cảnh chứng minh tương ứng; không phát lại tác động khi dựng lịch sử.

## Mức hoàn thiện

Đây là bản chơi được theo dạng hội thoại của dự án hiện tại. Các tương tác tìm đồ/so ảnh dùng thẻ chi tiết lớn; chưa có màn điều khiển Kiên đi lại hoặc ảnh trưng bày để soi từng điểm. Đường lặp dùng câu đố quan sát bằng mô tả; bản đồ dùng các điểm nối đơn giản. Đây là các chuyển thể gameplay cần nâng cấp bằng hình ảnh nếu muốn sát cách dàn cảnh trong DOCX.

Đang dùng lại ảnh trường, phòng ngủ, công viên và cánh cửa xanh có sẵn. Mái hiên nhà Vy, ảnh gia đình, ảnh trưng bày, chìa khóa và đường ven mương chưa có bộ tranh riêng. Lời ghi âm thể hiện bằng chữ, chưa có lồng tiếng. Thời lượng 70–100 phút trong tài liệu chưa được đo bằng lượt chơi thực tế.

## Kiểm tra

```powershell
python tests/validate_story.py
Godot_v4.7.2-stable_win64_console.exe --headless --editor --import --quit --path .
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/story_regression.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/chapter_regression.gd
```

Các kiểm thử dùng save trong `tests/.tmp/`, không sửa save thật. Bộ truyện đi qua năm lượt đại diện, bốn kết thúc, hủy xác nhận, nhánh không đủ điều kiện, dùng trợ giúp, tiếp tục câu đố đang dở, tải lại các mốc và sửa lời chào chưa hoàn tất. Bộ hồi quy dùng truyện chương 1 cũ làm fixture để giữ kiểm tra bộ đọc, fade, save cũ và giao thức minigame.

Kết quả trên Godot 4.7.2: **266 kiểm tra truyện + 147 kiểm tra hồi quy, 0 lỗi**; cả hai tiến trình thoát mã 0. Bộ hồi quy đã kiểm tra thêm save trỏ tới file truyện bị gỡ. Kiểm tra editor/import thành công. Trình kiểm tra dữ liệu xác nhận 54 cảnh đều tới được, 11 câu đố có đáp án hợp lệ và không thiếu asset hay đích chuyển cảnh. Log cuối không có lỗi script/resource hoặc cảnh báo rò tài nguyên.

Ảnh kiểm tra giao diện 1280 × 720 nằm trong `.godot/story_*.png`, được render bằng Godot OpenGL với save riêng. Chưa thực hiện playtest nghe âm thanh, thao tác cảm ứng trên thiết bị thật hoặc xuất bản build.

## Kiểm tra chuyển chương sau export

Trong PCK, `DirAccess.get_files_at()` liệt kê scene thành `chapter2.tscn.remap`; lọc riêng đuôi `.tscn` sẽ không tìm được chương tiếp theo và mở credits ngay sau chương 1. `GameManager._find_chapter_scene()` dùng `ResourceLoader.list_directory()` để nhận tên tài nguyên gốc trong cả editor và bản export. Xem [tài liệu ResourceLoader](https://docs.godotengine.org/en/4.7/classes/class_resourceloader.html#class-resourceloader-method-list-directory).

`tests/export_regression.gd` kiểm tra nạp nội dung JSON của cả năm chương, chuyển chương qua signal hoàn thành và chỉ ghi save hoàn tất khi tới credits sau chương 5. Chạy bằng Godot editor binary với PCK thật, trong thư mục riêng để không đọc nhầm tài nguyên từ project nguồn:

```powershell
$exportCheckDir = Join-Path (Get-Location) '.godot/export_check'
New-Item -ItemType Directory -Path $exportCheckDir -Force | Out-Null
Godot_v4.7.2-stable_win64_console.exe --headless --editor --path . --export-pack "WAY TO HOME" "$exportCheckDir/windows.pck"
Godot_v4.7.2-stable_win64_console.exe --headless --path "$exportCheckDir" --main-pack "$exportCheckDir/windows.pck" --script res://tests/export_regression.gd -- "--test-output-dir=$exportCheckDir/windows_save"
Godot_v4.7.2-stable_win64_console.exe --headless --editor --path . --export-pack "Way To Home" "$exportCheckDir/android.pck"
Godot_v4.7.2-stable_win64_console.exe --headless --path "$exportCheckDir" --main-pack "$exportCheckDir/android.pck" --script res://tests/export_regression.gd -- "--test-output-dir=$exportCheckDir/android_save"
```

Đã tái hiện lỗi trên PCK Windows cũ; sau sửa, cả PCK Windows và PCK từ preset Android đạt **24 kiểm tra, 0 lỗi** mỗi gói trên Godot 4.7.2. Cả năm JSON đều có trong gói với cấu hình export hiện tại. Đây là kiểm tra dữ liệu đóng gói và luồng chuyển chương; chưa kiểm tra APK trên thiết bị Android thật.

Sau khi sửa code cần export lại EXE/APK. Preset Windows hiện dùng `embed_pck=false`, nên khi chuyển bản game phải giữ EXE và PCK mới cùng thư mục.
