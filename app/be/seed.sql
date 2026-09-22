-- Dữ liệu mẫu cho dev/demo (BE-6, docs/docs_app/plan/be.md).
--
-- Idempotent: DELETE FROM tickets xoá sạch dữ liệu ticket cũ, và nhờ
-- ON DELETE CASCADE trên comments.ticket_id/activities.ticket_id (khai ở
-- DatabaseRepository.EnsureSchemaAsync), một câu DELETE này dọn sạch cả 3
-- bảng — chạy lại script này bao nhiêu lần cũng ra đúng 18 ticket như nhau.
--
-- CHỈ dùng cho DB dev/demo (container d4-mysql local). KHÔNG chạy trên DB có
-- dữ liệu cần giữ: DELETE FROM tickets xoá TOÀN BỘ bảng tickets hiện có.
--
-- SET NAMES utf8mb4 bắt buộc: mysql CLI client mặc định dùng character_set_client
-- = latin1 dù database/bảng là utf8mb4, nên nạp file qua CLI mà không khai báo
-- charset thì chữ có dấu bị hiểu nhầm là latin1 rồi re-encode → mojibake vĩnh
-- viễn trong bảng (đã tái hiện thật khi nạp qua docker exec mysql CLI).
SET NAMES utf8mb4;
DELETE FROM tickets;

-- Ghi rõ cột id để comments/activities bên dưới tham chiếu đúng ticket, và để
-- script chạy lại nhiều lần vẫn ra cùng một bộ id 1..18 (không phụ thuộc
-- AUTO_INCREMENT còn lại từ lần nạp trước).
INSERT INTO tickets
    (id, title, description, severity, category, status, reporter, assignee, created_at, updated_at, resolved_at)
VALUES
    (1, 'Trang chủ tải chậm vào giờ cao điểm',
        'Thời gian phản hồi trang chủ tăng gấp 3 lần vào khung 9-10h sáng, nghi do lượng truy cập đồng thời.',
        'high', 'app', 'in_progress', 'Hoà', 'Nam',
        NOW() - INTERVAL 2 DAY, (NOW() - INTERVAL 2 DAY) + INTERVAL 40 MINUTE, NULL),
    -- Ticket open + critical duy nhất trong bộ dữ liệu — bắt buộc để chỉ số
    -- open_critical của /stats khac 0.
    (2, 'Lỗi 502 sau khi triển khai bản mới',
        'Sau lần triển khai gần nhất, một phần yêu cầu trả về 502 Bad Gateway trong vài phút đầu.',
        'critical', 'app', 'open', 'Hoà', NULL,
        NOW() - INTERVAL 90 MINUTE, NOW() - INTERVAL 90 MINUTE, NULL),
    (3, 'Job đồng bộ dữ liệu bị treo giữa chừng',
        'Tiến trình đồng bộ định kỳ dừng lại ở bước giữa, không báo lỗi nhưng cũng không hoàn tất.',
        'medium', 'infra', 'in_progress', 'Bình', 'Lan',
        NOW() - INTERVAL 6 HOUR, (NOW() - INTERVAL 6 HOUR) + INTERVAL 25 MINUTE, NULL),
    (4, 'Dung lượng đĩa server lưu log gần đầy',
        NULL,
        'medium', 'infra', 'open', 'Lan', NULL,
        NOW() - INTERVAL 3 HOUR, NOW() - INTERVAL 3 HOUR, NULL),
    (5, 'Kết nối tới database bị timeout gián đoạn',
        'Vài truy vấn đọc/ghi báo timeout ngẫu nhiên, không lặp lại theo một điều kiện rõ ràng.',
        'high', 'database', 'resolved', 'Nam', 'Hoà',
        NOW() - INTERVAL 5 DAY, (NOW() - INTERVAL 5 DAY) + INTERVAL 130 MINUTE, (NOW() - INTERVAL 5 DAY) + INTERVAL 130 MINUTE),
    (6, 'Sai lệch dữ liệu tồn kho giữa hai bảng',
        'Đối chiếu định kỳ phát hiện số liệu tồn kho giữa bảng tổng hợp và bảng chi tiết không khớp.',
        'low', 'database', 'closed', 'Bình', 'Nam',
        NOW() - INTERVAL 10 DAY, (NOW() - INTERVAL 10 DAY) + INTERVAL 340 MINUTE, (NOW() - INTERVAL 10 DAY) + INTERVAL 320 MINUTE),
    (7, 'Cảnh báo chứng chỉ TLS sắp hết hạn',
        'Hệ thống giám sát báo chứng chỉ TLS còn hiệu lực dưới 14 ngày, cần gia hạn trước khi hết hạn.',
        'medium', 'security', 'open', 'Lan', 'Hoà',
        NOW() - INTERVAL 1 DAY, NOW() - INTERVAL 1 DAY, NULL),
    (8, 'Phát hiện đăng nhập từ địa chỉ IP lạ',
        'Log xác thực ghi nhận vài lần đăng nhập thành công từ địa chỉ IP chưa từng xuất hiện trước đó.',
        'high', 'security', 'in_progress', 'Nam', 'Bình',
        NOW() - INTERVAL 4 HOUR, (NOW() - INTERVAL 4 HOUR) + INTERVAL 20 MINUTE, NULL),
    (9, 'Mất kết nối mạng giữa hai khu vực',
        'Liên lạc giữa hai khu vực mạng gián đoạn hoàn toàn trong khoảng 45 phút.',
        'critical', 'network', 'resolved', 'Hoà', 'Lan',
        NOW() - INTERVAL 7 DAY, (NOW() - INTERVAL 7 DAY) + INTERVAL 45 MINUTE, (NOW() - INTERVAL 7 DAY) + INTERVAL 45 MINUTE),
    (10, 'Độ trễ mạng tăng đột biến lúc trưa',
        NULL,
        'low', 'network', 'closed', 'Bình', 'Hoà',
        NOW() - INTERVAL 12 DAY, (NOW() - INTERVAL 12 DAY) + INTERVAL 100 MINUTE, (NOW() - INTERVAL 12 DAY) + INTERVAL 80 MINUTE),
    (11, 'Job backup hằng đêm bị lỗi giữa chừng',
        'Backup hằng đêm báo lỗi ghi file ở khoảng 70% tiến độ, các lần trước đó đều chạy xong bình thường.',
        'medium', 'infra', 'resolved', 'Lan', 'Nam',
        NOW() - INTERVAL 4 DAY, (NOW() - INTERVAL 4 DAY) + INTERVAL 260 MINUTE, (NOW() - INTERVAL 4 DAY) + INTERVAL 260 MINUTE),
    (12, 'Trang quản trị phản hồi chậm',
        NULL,
        'low', 'app', 'open', 'Nam', NULL,
        NOW() - INTERVAL 8 HOUR, NOW() - INTERVAL 8 HOUR, NULL),
    (13, 'Báo cáo tháng hiển thị sai biểu đồ',
        'Biểu đồ trong báo cáo tháng không khớp với bảng số liệu chi tiết cùng kỳ.',
        'low', 'app', 'closed', 'Hoà', 'Lan',
        NOW() - INTERVAL 15 DAY, (NOW() - INTERVAL 15 DAY) + INTERVAL 170 MINUTE, (NOW() - INTERVAL 15 DAY) + INTERVAL 150 MINUTE),
    (14, 'Cảnh báo dung lượng ổ đĩa gần ngưỡng',
        NULL,
        'medium', 'other', 'open', 'Bình', NULL,
        NOW() - INTERVAL 5 HOUR, NOW() - INTERVAL 5 HOUR, NULL),
    (15, 'Yêu cầu nâng cấp RAM cho server test',
        'Server môi trường test thường xuyên chậm do thiếu bộ nhớ khi chạy đồng thời nhiều tiến trình.',
        'low', 'other', 'in_progress', 'Lan', 'Hoà',
        NOW() - INTERVAL 1 DAY, (NOW() - INTERVAL 1 DAY) + INTERVAL 30 MINUTE, NULL),
    (16, 'Token xác thực hết hạn quá sớm',
        'Người dùng báo bị đăng xuất ngoài ý muốn trước thời gian hết hạn công bố của token.',
        'high', 'security', 'resolved', 'Nam', 'Bình',
        NOW() - INTERVAL 6 DAY, (NOW() - INTERVAL 6 DAY) + INTERVAL 95 MINUTE, (NOW() - INTERVAL 6 DAY) + INTERVAL 95 MINUTE),
    (17, 'Hàng đợi xử lý đơn bị tắc nghẽn',
        'Số lượng đơn chờ xử lý trong hàng đợi tăng liên tục, tốc độ xử lý không theo kịp tốc độ nhận mới.',
        'critical', 'infra', 'in_progress', 'Hoà', 'Nam',
        NOW() - INTERVAL 2 HOUR, (NOW() - INTERVAL 2 HOUR) + INTERVAL 15 MINUTE, NULL),
    (18, 'Truy vấn tìm kiếm chậm do chỉ mục cũ',
        'Truy vấn tìm kiếm trên bảng lịch sử chạy chậm dần theo thời gian, nghi do chỉ mục không còn phù hợp với dữ liệu hiện tại.',
        'medium', 'database', 'closed', 'Bình', 'Lan',
        NOW() - INTERVAL 20 DAY, (NOW() - INTERVAL 20 DAY) + INTERVAL 420 MINUTE, (NOW() - INTERVAL 20 DAY) + INTERVAL 400 MINUTE);

-- Một dòng 'created' cho MỌI ticket, actor là reporter, mốc thời gian trùng
-- created_at của ticket đó — ticket nào cũng phải có lịch sử "được tạo".
INSERT INTO activities (ticket_id, actor, action, from_value, to_value, created_at) VALUES
    (1, 'Hoà', 'created', NULL, NULL, NOW() - INTERVAL 2 DAY),
    (2, 'Hoà', 'created', NULL, NULL, NOW() - INTERVAL 90 MINUTE),
    (3, 'Bình', 'created', NULL, NULL, NOW() - INTERVAL 6 HOUR),
    (4, 'Lan', 'created', NULL, NULL, NOW() - INTERVAL 3 HOUR),
    (5, 'Nam', 'created', NULL, NULL, NOW() - INTERVAL 5 DAY),
    (6, 'Bình', 'created', NULL, NULL, NOW() - INTERVAL 10 DAY),
    (7, 'Lan', 'created', NULL, NULL, NOW() - INTERVAL 1 DAY),
    (8, 'Nam', 'created', NULL, NULL, NOW() - INTERVAL 4 HOUR),
    (9, 'Hoà', 'created', NULL, NULL, NOW() - INTERVAL 7 DAY),
    (10, 'Bình', 'created', NULL, NULL, NOW() - INTERVAL 12 DAY),
    (11, 'Lan', 'created', NULL, NULL, NOW() - INTERVAL 4 DAY),
    (12, 'Nam', 'created', NULL, NULL, NOW() - INTERVAL 8 HOUR),
    (13, 'Hoà', 'created', NULL, NULL, NOW() - INTERVAL 15 DAY),
    (14, 'Bình', 'created', NULL, NULL, NOW() - INTERVAL 5 HOUR),
    (15, 'Lan', 'created', NULL, NULL, NOW() - INTERVAL 1 DAY),
    (16, 'Nam', 'created', NULL, NULL, NOW() - INTERVAL 6 DAY),
    (17, 'Hoà', 'created', NULL, NULL, NOW() - INTERVAL 2 HOUR),
    (18, 'Bình', 'created', NULL, NULL, NOW() - INTERVAL 20 DAY);

-- Với ticket không còn ở 'open' (13 ticket), thêm một dòng status_changed
-- ghi lại bước chuyển từ 'open' sang trạng thái hiện tại, actor là assignee
-- nếu có (người xử lý), không thì là reporter; created_at trùng updated_at
-- của ticket đó (thời điểm trạng thái được cập nhật lần cuối).
INSERT INTO activities (ticket_id, actor, action, from_value, to_value, created_at) VALUES
    (1, 'Nam', 'status_changed', 'open', 'in_progress', (NOW() - INTERVAL 2 DAY) + INTERVAL 40 MINUTE),
    (3, 'Lan', 'status_changed', 'open', 'in_progress', (NOW() - INTERVAL 6 HOUR) + INTERVAL 25 MINUTE),
    (5, 'Hoà', 'status_changed', 'open', 'resolved', (NOW() - INTERVAL 5 DAY) + INTERVAL 130 MINUTE),
    (6, 'Nam', 'status_changed', 'open', 'closed', (NOW() - INTERVAL 10 DAY) + INTERVAL 340 MINUTE),
    (8, 'Bình', 'status_changed', 'open', 'in_progress', (NOW() - INTERVAL 4 HOUR) + INTERVAL 20 MINUTE),
    (9, 'Lan', 'status_changed', 'open', 'resolved', (NOW() - INTERVAL 7 DAY) + INTERVAL 45 MINUTE),
    (10, 'Hoà', 'status_changed', 'open', 'closed', (NOW() - INTERVAL 12 DAY) + INTERVAL 100 MINUTE),
    (11, 'Nam', 'status_changed', 'open', 'resolved', (NOW() - INTERVAL 4 DAY) + INTERVAL 260 MINUTE),
    (13, 'Lan', 'status_changed', 'open', 'closed', (NOW() - INTERVAL 15 DAY) + INTERVAL 170 MINUTE),
    (15, 'Hoà', 'status_changed', 'open', 'in_progress', (NOW() - INTERVAL 1 DAY) + INTERVAL 30 MINUTE),
    (16, 'Bình', 'status_changed', 'open', 'resolved', (NOW() - INTERVAL 6 DAY) + INTERVAL 95 MINUTE),
    (17, 'Nam', 'status_changed', 'open', 'in_progress', (NOW() - INTERVAL 2 HOUR) + INTERVAL 15 MINUTE),
    (18, 'Lan', 'status_changed', 'open', 'closed', (NOW() - INTERVAL 20 DAY) + INTERVAL 420 MINUTE);

-- Bình luận mẫu cho một vài ticket có nhiều hoạt động nhất — không cần phủ
-- hết 18 ticket, chỉ đủ để demo phần comment trong UI.
INSERT INTO comments (ticket_id, author, body, created_at) VALUES
    (1, 'Nam', 'Đã xem lại dashboard, nghi do số lượng kết nối đồng thời vượt ngưỡng pool hiện tại.',
        (NOW() - INTERVAL 2 DAY) + INTERVAL 15 MINUTE),
    (1, 'Hoà', 'Đang thử tăng giới hạn pool ở môi trường test trước khi áp dụng production.',
        (NOW() - INTERVAL 2 DAY) + INTERVAL 35 MINUTE),
    (2, 'Hoà', 'Đã rollback về bản trước, đang theo dõi tỷ lệ lỗi 502 có giảm không.',
        NOW() - INTERVAL 60 MINUTE),
    (5, 'Hoà', 'Kiểm tra thì thấy số kết nối tới database vượt giới hạn cấu hình vào giờ cao điểm.',
        (NOW() - INTERVAL 5 DAY) + INTERVAL 60 MINUTE),
    (9, 'Lan', 'Đã liên hệ đội hạ tầng mạng, xác nhận là sự cố trên đường truyền giữa hai khu vực.',
        (NOW() - INTERVAL 7 DAY) + INTERVAL 20 MINUTE),
    (16, 'Bình', 'Kiểm tra cấu hình thời gian sống của token, thấy bị đặt sai đơn vị (giây thay vì phút).',
        (NOW() - INTERVAL 6 DAY) + INTERVAL 50 MINUTE),
    (17, 'Nam', 'Hàng đợi đang tăng do một tiến trình xử lý bị dừng, đang khởi động lại.',
        (NOW() - INTERVAL 2 HOUR) + INTERVAL 5 MINUTE);
