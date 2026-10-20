# Dữ liệu kiểm thử bộ đọc cũ

Bốn JSON này chỉ phục vụ `tests/chapter_regression.gd`: kiểm tra các nhánh theo file, lịch sử hội thoại, nền/nhạc và tương thích save của `ChapterBase`. Không có scene gameplay hiện hành trỏ tới thư mục này.

Nội dung game đang dùng nằm trong `data/story/chapter_01.json` đến `chapter_05.json`.

| File | Tác dụng trong kiểm thử |
| --- | --- |
| [main_story.json](main_story.json) | File đầu của truyện cũ, dùng thử đọc thoại, đổi nền/nhạc, thời gian và hai lựa chọn cuối file. |
| [dy.json](dy.json) | Nhánh đồng ý, dùng thử chuyển `next_file`, reset index và Continue đúng nhánh. |
| [tc.json](tc.json) | Nhánh từ chối, kiểm tra độc lập với nhánh đồng ý để tránh lưu nhầm file. |
| [endbranch.json](endbranch.json) | Điểm nối chung sau hai nhánh, dùng thử Continue xuyên file và hoàn thành chương. |

Các file dùng JSON dạng mảng; `ChapterBase.load_story()` chuẩn hóa thành `episodes/scenes/dialogues`. `next_file` được giải tương đối theo thư mục file đang đọc. Không chèn comment vào JSON; ghi chú thay đổi fixture tại README này.
