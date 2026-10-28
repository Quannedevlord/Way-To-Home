# Nhạc theo diễn biến truyện

Thư viện cấu hình: `data/audio/music.json`. Đổi `crossfade_seconds` để chỉnh thời gian chuyển nhạc (mặc định 1,5 giây); từng ID có `title`, `path`, `loop`. Có thể đặt `duration` trên sự kiện `change_music` để đổi thời gian riêng tại một dòng.

| ID | File đã tìm thấy trong `assets/backgrounds/audio/bgm/` | Loop |
| --- | --- | --- |
| BGM_DAILY | Before the Bell.mp3 | Có |
| BGM_DREAM | Seventeen Twenty.mp3 | Có |
| BGM_INVESTIGATION | Traces of Her.mp3 | Có |
| BGM_GRIEF | The Empty Chair.mp3 | Có |
| BGM_TRUST | Words Left Unsaid.mp3 | Có |
| BGM_FINAL_ROAD | One Last Road Home.mp3 | Có |
| BGM_ENDING_E1 | The Light Is Still On.mp3 | Không |
| BGM_ENDING_E2 | Goodbye by the Window.mp3 | Không |
| BGM_ENDING_E3 | Home Without You.mp3 | Không |
| BGM_ENDING_E4 | Tomorrow Never Comes.mp3 | Không |

Cả 10 ID đã được gán file âm thanh có trong dự án. Nếu sau này ID chưa gán, đường dẫn thiếu hoặc tài nguyên không phải âm thanh, hệ thống sẽ giảm nhạc cũ về im lặng, cảnh báo một lần cho mỗi ID trong phiên chơi và tiếp tục truyện. Sau khi thay file hoặc cấu hình, chạy lại game để nạp thư viện nhạc mới. Hai preset export đều bao gồm JSON truyện và thư viện nhạc.

## Điểm chuyển chính

Chỉ số dòng bên dưới bắt đầu từ 0, tính trong mảng `dialogues` của cảnh. Nhạc được đặt ở dòng truyện thật, không suy ra từ tên chapter hay kiểm tra liên tục trong `_process`.

| Cảnh | Cue |
| --- | --- |
| c1s3 | DAILY ở dòng 0; DREAM ở dòng 3 khi bước vào mơ |
| c1s5 | DREAM khi còn nghe Vy; DAILY ở dòng 2 khi tỉnh |
| c2a | DREAM ở dòng 0; DAILY ở dòng 24 khi tỉnh |
| c2b, c2hint, c2outside_meal | DAILY khi ra ngoài mua cơm và nói chuyện |
| c2s5 | DREAM dòng 0 chỉ khi `route2=outside`; INVESTIGATION dòng 10 chỉ khi `route2=sleep`; INVESTIGATION dòng 12 khi mở ảnh Thư gửi |
| c3s1, c3a1 | INVESTIGATION khi xem danh mục tranh, đối chiếu vòng/ảnh |
| c3a2, c3record, c3borrow | GRIEF khi thăm gia đình, nghe lời nhắn |
| c3b1, c3loop | DREAM khi khám phá đường lặp |
| c3b2 | GRIEF khi Vy nói về cuộc cãi nhau |
| c3b3 | DAILY tại nhà Kiên; GRIEF dòng 4 khi tới gia đình Vy |
| c3s2, c3truth | DREAM lúc gặp lại; GRIEF từ c3s2 dòng 5 và khi nói sự thật |
| c4s1 | DAILY ở dòng 0; TRUST dòng 3 khi Thư đề nghị lắng nghe |
| c4support, c4hub, c4summary, c4c | TRUST cho hỗ trợ và chuẩn bị, kể cả quay lại từ nhánh khác |
| c4a | GRIEF cho lời nhắn cuối và xác minh sự việc |
| c4b | DREAM lúc vào mơ; TRUST dòng 4 khi bắt đầu lời chào |
| c4b1, c4b2, c4reread | TRUST khi Vy tự viết/đọc lời chào; giữ TRUST lúc chép lại sau khi tỉnh |
| c4anchor | TRUST khi chuẩn bị; DREAM dòng 1 lúc thử trong mơ; TRUST dòng 3 khi tỉnh |
| c4s2 | TRUST trước khi ngủ; FINAL_ROAD dòng 6 khi chuyến đi cuối bắt đầu |
| c5s1–c5choice, e4warning | FINAL_ROAD, kể cả xác nhận hoặc đổi ý |
| e1, e2, e3 | Nhạc ending tương ứng từ dòng đầu, giữ xuyên đoạn trở lại đời thực và Credit |
| e4 | ENDING_E4 ở dòng 0 hoặc 1 theo `anchor_ready`, chỉ sau khi xác nhận ở lại |

`c3record` và `c4a` hiện chỉ có thoại chữ của “Vy trong ghi âm”. Không có sự kiện phát bản ghi hay file thu âm lời nhắn trong dự án; do đó không hạ nhạc theo một khoảng thời gian giả định. Nếu sau này thêm bản thu thật, cần nối việc hạ/khôi phục nhạc với player phát bản thu và tín hiệu `finished`/hủy phát.

## Trạng thái và tương thích

`MusicManager` là autoload dùng hai `AudioStreamPlayer` trên bus `Music`. Tween đổi gain của player nên giữ nguyên âm lượng và mute trên bus, không can thiệp SFX. Khi đổi liên tiếp, tween cũ bị hủy, player được tái sử dụng và player thừa dừng/gỡ stream khi fade xong. Yêu cầu trùng bản đang phát giữ vị trí; bản ending đã kết thúc không tự phát lại khi tới Credit.

Cue chỉ được xử lý sau bộ lọc `when` hiện có. `requires`, `choices`, `go`, `next` và các cờ truyện giữ nguyên. Save/checkpoint thêm `music_state` gồm cue, vị trí và trạng thái đã phát hết. Khi Continue, lịch sử chỉ gom cue cuối rồi khôi phục một lần. Save cũ có lịch sử lấy cue mới từ dòng đã đọc; save chỉ có index lọc `when` trước khi dựng lại các dòng trong cảnh. Không phát lại SFX hoặc ghi âm khi dựng lịch sử.

Menu dùng bản `Dream Portal.mp3` có sẵn. Credit giữ player ending đang phát; mở Credit độc lập không có ending dùng `The_Way_Back_Home.mp3` có sẵn. Nhạc nền lặp, bốn ending mặc định phát một lần; có thể đổi `loop` riêng cho từng bản.

## Kiểm tra

- `python tests/validate_story.py`: đồ thị truyện, tài nguyên, ID nhạc và danh sách ID chưa gán.
- `Godot --headless --path . --script res://tests/music_regression.gd`: crossfade, yêu cầu dồn, loop, âm lượng/mute, SFX, tài nguyên thiếu, Continue và save cũ ở hai tuyến c2s5.
- `Godot --headless --path . --script res://tests/story_regression.gd`: chơi qua các tuyến của cả 5 chapter, chuẩn bị, điều kiện ending, đổi ý, checkpoint và Credit.
- `Godot --headless --path . --script res://tests/chapter_regression.gd`: bộ đọc và sự kiện dùng đường dẫn trong fixture truyện cũ.

Các bài Godot dùng save riêng trong `tests/.tmp/`.
