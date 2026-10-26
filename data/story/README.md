# Ghi chú dữ liệu truyện

JSON không có cú pháp comment. Giữ các file truyện là JSON hợp lệ; dùng tài liệu này để tra tác dụng các trường. Mã xử lý nằm ở [StoryChapter](../../scenes/chapters/base/story_chapter.gd) và [ChapterBase](../../scenes/chapters/base/chapter_base.gd).

## Vai trò từng file

| File | Nội dung chính |
| --- | --- |
| [chapter_01.json](chapter_01.json) | Người lạ trong giấc mơ: mở đầu câu chuyện, các lựa chọn và tương tác đầu tiên. |
| [chapter_02.json](chapter_02.json) | Chiếc vòng không có người nhận: hai tuyến tìm hiểu, lưu lựa chọn và manh mối cho chương sau. |
| [chapter_03.json](chapter_03.json) | Người vắng mặt trong bức ảnh: các tuyến tìm hiểu thân phận và xác minh lời nhắn. |
| [chapter_04.json](chapter_04.json) | Điều chưa kịp nói: mốc `preparation`, các việc chuẩn bị có thể quay lại và phần tổng kết. |
| [chapter_05.json](chapter_05.json) | Đường về nhà: mốc `final_choice`, điều kiện mở và xác nhận bốn kết thúc E1–E4. |

Mỗi file hiện có một episode chứa các cảnh. `StoryChapter.go_to_scene()` tìm ID trong episode đầu; các chapter chuyển tiếp qua `GameManager` khi cảnh kết thúc chương.

## Cấu trúc cảnh và dòng

| Trường | Tác dụng |
| --- | --- |
| `episodes[].scenes[]` | Danh sách cảnh. Scene đầu là nơi bắt đầu chương; thứ tự các cảnh khác không thay thế các liên kết bằng ID. |
| `scene.id` | ID duy nhất trong chương, được `go` và `next` dùng làm đích. Giữ ổn định khi sửa nội dung. |
| `scene.location` | Tên địa điểm, được đưa vào dòng phân cách chat khi mở cảnh. |
| `scene.dialogues` | Các dòng thoại/lời dẫn/tương tác của cảnh, đọc theo thứ tự. |
| `scene.next` | ID cảnh sau hoặc mảng `{ "when": {...}, "go": "..." }`; lấy nhánh đầu tiên thỏa điều kiện. Nhánh cuối có thể dùng `when: {}` làm mặc định. |
| `scene.next: ""` | Khi đọc hết cảnh sẽ hoàn thành chương nếu lựa chọn trên dòng chưa chuyển sang cảnh khác. |
| `scene.checkpoint` | Ghi mốc ở đầu cảnh, gồm vị trí đọc, trạng thái câu đố và cờ truyện. |
| `line.type` | Chọn cách hiển thị, thường là `dialogue`, `narration` hoặc `image`. Thiếu type thì suy ra từ việc có `speaker` hay không. |
| `line.speaker`, `line.text` | Tên người nói và nội dung. Bộ đọc chuẩn hóa `text` thành `message`; cũng chấp nhận `message`. |
| `line.time` | Chuỗi giờ hiển thị trên đồng hồ; chiến dịch giữ giờ gần nhất cho đến khi có giá trị mới. |
| `line.avatar`, `line.illustration` | Đường dẫn ảnh đại diện/ảnh minh họa. |
| `line.use_as_background` | Đặt `false` để ảnh minh họa chỉ hiện trong chat, không đổi nền. |
| `line.sfx` | Tên hiệu ứng không kèm đuôi, ví dụ `schoolbell` tìm `res://assets/sound_effect/schoolbell.mp3`. |
| `line.when` | Chỉ đọc dòng nếu tất cả cờ bằng giá trị yêu cầu; cờ chưa có được xem là `false`. |
| `line.set` | Gán cờ khi đọc dòng mới. Các cờ nằm trong `GameManager.campaign_state`. |
| `line.clue` | Ghi manh mối gồm `id`, `title`, `source`, `text`; cùng ID sẽ cập nhật mục cũ trong sổ. |
| `line.summary` | Sự hiện diện của trường này yêu cầu thay nội dung dòng bằng tổng kết ba việc chuẩn bị. |
| `line.choices` | Danh sách lựa chọn, chặn đọc tiếp cho đến khi được giải quyết. |
| `line.event`, `line.events` | Một sự kiện hoặc danh sách sự kiện chạy tuần tự. Với dữ liệu có cả hai, bộ đọc ưu tiên `events`. |

## Avatar theo lời thoại

Các câu thoại của Kiên, Thư, Vy và lời ghi âm của Vy có trường `avatar` riêng. Chọn ảnh theo cảm xúc của câu nói:

| Tên ảnh trong `assets/avatars/` | Biểu cảm |
| --- | --- |
| `Avatar_Kien.png`, `Avatar_Thu.png`, `Avatar_Vy.png` | Cười nhẹ, vui hoặc nhẹ nhõm. |
| `Avatar_*_NoE.png` | Bình thường, suy nghĩ hoặc nói chuyện nghiêm túc. |
| `Avatar_*_Sad.png` | Buồn, lo lắng hoặc day dứt. |
| `Avatar_*_Sudden.png` | Ngạc nhiên, giật mình hoặc hoảng hốt. |

Ví dụ: `"avatar": "res://assets/avatars/Avatar_Vy_Sad.png"`. Nếu không ghi `avatar`, game dùng ảnh mặc định theo tên người nói trong scene. Giọng nói chưa rõ danh tính và nhân vật chưa có ảnh riêng vẫn dùng ảnh thay thế.

Khi một nhân vật nói liên tiếp, avatar chỉ được ẩn bớt nếu biểu cảm vẫn giống câu trước. Đổi ảnh sẽ hiện lại avatar để người chơi thấy thay đổi. Lịch sử chat lưu cả đường dẫn avatar, nên tiếp tục ván đã lưu vẫn giữ biểu cảm của những câu đã đọc. Lịch sử được lưu trước khi bổ sung avatar vẫn dùng ảnh mặc định cho những dòng cũ chưa có trường này.

## Lựa chọn

| Trường | Tác dụng |
| --- | --- |
| `text` | Chữ trên nút và câu trả lời thêm vào lịch sử khi lựa chọn được chấp nhận. |
| `avatar` | Biểu cảm của nhân vật chính khi câu lựa chọn được thêm vào chat; được giữ qua bước xác nhận và khi lưu/tiếp tục. |
| `description` | Mô tả bổ sung trên nút khả dụng. |
| `when` | Quyết định có hiển thị lựa chọn hay không. |
| `requires` | Quyết định có được bấm hay không; lựa chọn vẫn hiện khi khóa, kèm việc còn thiếu. |
| `confirm` | Mở bước xác nhận trước khi áp dụng tác động. Nút quay lại chưa ghi cờ hay chọn kết thúc. |
| `set`, `clue` | Tác động khi lựa chọn được chấp nhận, sau bước xác nhận nếu có. |
| `go` | ID cảnh đích trong cùng chương; chuỗi rỗng hoàn thành chương. Không có `go` thì đọc tiếp dòng sau. |
| `checkpoint` | Tải mốc đã lưu thay cho xử lý lựa chọn thông thường. |

`when` và `requires` so sánh bằng chính xác từng giá trị, không phải biểu thức GDScript. Bộ truyện dùng các cờ boolean như `memory_verified`, `farewell_ready`, `anchor_ready` để giải thích việc còn thiếu trên nút kết thúc E1.

## Sự kiện và câu đố

| Trường/loại | Tác dụng |
| --- | --- |
| `type: "change_background"` hoặc `"background"` | Đổi ảnh theo `path`; `duration` tính bằng giây, `fade: false` đổi ngay. |
| `type: "change_music"` | Đổi và phát nhạc nền từ `path`. |
| `type: "fade_in"` / `"fade_out"` | Làm sáng/tối màn hình trong `duration` giây; bộ đọc đợi hiệu ứng hoàn tất. |
| `type: "minigame"` | Mở scene câu đố, khóa thoại và chờ signal `finished(result)`. |
| `id` của minigame | Khóa ổn định để lưu kết quả và nhận diện ván đã xong; dùng duy nhất trong chiến dịch. |
| `scene` của minigame | Đường dẫn PackedScene, hiện dùng `res://scenes/minigames/story_puzzle.tscn`. |
| `config` | Truyền cho `configure()` trước khi minigame vào cây scene. |
| `set`, `clue` trên event minigame | Chỉ áp dụng khi nhận `outcome: "done"`, không áp dụng ngay lúc mở câu đố. |
| `branches` | Giao thức của ChapterBase: đối chiếu `result.outcome` để chuyển `next_file` hoặc `next` là chỉ số dòng. Chiến dịch chủ yếu dùng cờ và ID cảnh. |

Cấu hình `story_puzzle.gd`:

| Trường | Tác dụng |
| --- | --- |
| `title`, `instruction` | Tiêu đề và hướng dẫn thao tác. |
| `items` | Danh sách chữ trên các thẻ/điểm. |
| `answer` | Các chỉ số trong `items`, bắt đầu từ 0; phải không rỗng và không trùng. |
| `mode: "select"` | Chọn đủ chi tiết đúng, không cần theo thứ tự. |
| `mode: "order"` | Chọn đúng trình tự đáp án; sai thì xóa chuỗi đang chọn. |
| `mode: "path"` | Cùng luật thứ tự, có thêm bảng nối điểm bằng chuột hoặc cảm ứng. |
| `image` | Ảnh minh họa tùy chọn của câu đố. |
| `found`, `hint`, `success`, `help_label` | Chữ phản hồi khi chọn đúng, gợi ý, hoàn tất và nhãn nút trợ giúp. |

Trợ giúp mở sau ít nhất một lần chọn, hoàn thiện cùng đáp án và vẫn trả `outcome: "done"`. Người chơi cần bấm Tiếp tục để đóng câu đố. `selected`, `attempts`, `solved`, `assisted` được lưu để tiếp tục ván dở.

Chạy `python tests/validate_story.py` sau khi sửa dữ liệu để kiểm tra asset, ID, đích cảnh và đáp án. Kiểm tra này chỉ xét liên kết tĩnh; dùng thêm `tests/story_regression.gd` để kiểm tra các tuyến và điều kiện khi chơi.
