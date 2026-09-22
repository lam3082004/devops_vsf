-- Dữ liệu mẫu cho dev/demo (BE-6, docs/docs_app/plan/be.md).
--
-- Idempotent: DELETE FROM tickets xoá sạch dữ liệu ticket cũ, và nhờ
-- ON DELETE CASCADE trên comments.ticket_id/activities.ticket_id (khai ở
-- DatabaseRepository.EnsureSchemaAsync), một câu DELETE này dọn sạch cả 3
-- bảng — chạy lại script này bao nhiêu lần cũng ra đúng 18 ticket như nhau.
--
-- CHỈ dùng cho DB dev/demo (container d4-mysql local). KHÔNG chạy trên DB có
-- dữ liệu cần giữ: DELETE FROM tickets xoá TOÀN BỘ bảng tickets hiện có.
DELETE FROM tickets;

-- Ghi rõ cột id để comments/activities bên dưới tham chiếu đúng ticket, và để
-- script chạy lại nhiều lần vẫn ra cùng một bộ id 1..18 (không phụ thuộc
-- AUTO_INCREMENT còn lại từ lần nạp trước).
INSERT INTO tickets
    (id, title, description, severity, category, status, reporter, assignee, created_at, updated_at, resolved_at)
VALUES
    (1, 'Trang chu tai cham vao gio cao diem',
        'Thoi gian phan hoi trang chu tang gap 3 lan vao khung 9-10h sang, nghi do luong truy cap dong thoi.',
        'high', 'app', 'in_progress', 'Hoa', 'Nam',
        NOW() - INTERVAL 2 DAY, (NOW() - INTERVAL 2 DAY) + INTERVAL 40 MINUTE, NULL),
    -- Ticket open + critical duy nhất trong bộ dữ liệu — bắt buộc để chỉ số
    -- open_critical của /stats khac 0.
    (2, 'Loi 502 sau khi trien khai ban moi',
        'Sau lan trien khai gan nhat, mot phan yeu cau tra ve 502 Bad Gateway trong vai phut dau.',
        'critical', 'app', 'open', 'Hoa', NULL,
        NOW() - INTERVAL 90 MINUTE, NOW() - INTERVAL 90 MINUTE, NULL),
    (3, 'Job dong bo du lieu bi treo giua chung',
        'Tien trinh dong bo dinh ky dung lai o buoc giua, khong bao loi nhung cung khong hoan tat.',
        'medium', 'infra', 'in_progress', 'Binh', 'Lan',
        NOW() - INTERVAL 6 HOUR, (NOW() - INTERVAL 6 HOUR) + INTERVAL 25 MINUTE, NULL),
    (4, 'Dung luong dia server luu log gan day',
        NULL,
        'medium', 'infra', 'open', 'Lan', NULL,
        NOW() - INTERVAL 3 HOUR, NOW() - INTERVAL 3 HOUR, NULL),
    (5, 'Ket noi toi database bi timeout gian doan',
        'Vai truy van doc/ghi bao timeout ngau nhien, khong lap lai theo mot dieu kien ro rang.',
        'high', 'database', 'resolved', 'Nam', 'Hoa',
        NOW() - INTERVAL 5 DAY, (NOW() - INTERVAL 5 DAY) + INTERVAL 130 MINUTE, (NOW() - INTERVAL 5 DAY) + INTERVAL 130 MINUTE),
    (6, 'Sai lech du lieu ton kho giua hai bang',
        'Doi chieu dinh ky phat hien so lieu ton kho giua bang tong hop va bang chi tiet khong khop.',
        'low', 'database', 'closed', 'Binh', 'Nam',
        NOW() - INTERVAL 10 DAY, (NOW() - INTERVAL 10 DAY) + INTERVAL 340 MINUTE, (NOW() - INTERVAL 10 DAY) + INTERVAL 320 MINUTE),
    (7, 'Canh bao chung chi TLS sap het han',
        'He thong giam sat bao chung chi TLS con hieu luc duoi 14 ngay, can gia han truoc khi het han.',
        'medium', 'security', 'open', 'Lan', 'Hoa',
        NOW() - INTERVAL 1 DAY, NOW() - INTERVAL 1 DAY, NULL),
    (8, 'Phat hien dang nhap tu dia chi IP la',
        'Log xac thuc ghi nhan vai lan dang nhap thanh cong tu dia chi IP chua tung xuat hien truoc do.',
        'high', 'security', 'in_progress', 'Nam', 'Binh',
        NOW() - INTERVAL 4 HOUR, (NOW() - INTERVAL 4 HOUR) + INTERVAL 20 MINUTE, NULL),
    (9, 'Mat ket noi mang giua hai khu vuc',
        'Lien lac giua hai khu vuc mang gian doan hoan toan trong khoang 45 phut.',
        'critical', 'network', 'resolved', 'Hoa', 'Lan',
        NOW() - INTERVAL 7 DAY, (NOW() - INTERVAL 7 DAY) + INTERVAL 45 MINUTE, (NOW() - INTERVAL 7 DAY) + INTERVAL 45 MINUTE),
    (10, 'Do tre mang tang dot bien luc trua',
        NULL,
        'low', 'network', 'closed', 'Binh', 'Hoa',
        NOW() - INTERVAL 12 DAY, (NOW() - INTERVAL 12 DAY) + INTERVAL 100 MINUTE, (NOW() - INTERVAL 12 DAY) + INTERVAL 80 MINUTE),
    (11, 'Job backup hang dem bi loi giua chung',
        'Backup hang dem bao loi ghi file o khoang 70% tien do, cac lan truoc do deu chay xong binh thuong.',
        'medium', 'infra', 'resolved', 'Lan', 'Nam',
        NOW() - INTERVAL 4 DAY, (NOW() - INTERVAL 4 DAY) + INTERVAL 260 MINUTE, (NOW() - INTERVAL 4 DAY) + INTERVAL 260 MINUTE),
    (12, 'Trang quan tri phan hoi cham',
        NULL,
        'low', 'app', 'open', 'Nam', NULL,
        NOW() - INTERVAL 8 HOUR, NOW() - INTERVAL 8 HOUR, NULL),
    (13, 'Bao cao thang hien thi sai bieu do',
        'Bieu do trong bao cao thang khong khop voi bang so lieu chi tiet cung ky.',
        'low', 'app', 'closed', 'Hoa', 'Lan',
        NOW() - INTERVAL 15 DAY, (NOW() - INTERVAL 15 DAY) + INTERVAL 170 MINUTE, (NOW() - INTERVAL 15 DAY) + INTERVAL 150 MINUTE),
    (14, 'Canh bao dung luong o dia gan nguong',
        NULL,
        'medium', 'other', 'open', 'Binh', NULL,
        NOW() - INTERVAL 5 HOUR, NOW() - INTERVAL 5 HOUR, NULL),
    (15, 'Yeu cau nang cap RAM cho server test',
        'Server moi truong test thuong xuyen cham do thieu bo nho khi chay dong thoi nhieu tien trinh.',
        'low', 'other', 'in_progress', 'Lan', 'Hoa',
        NOW() - INTERVAL 1 DAY, (NOW() - INTERVAL 1 DAY) + INTERVAL 30 MINUTE, NULL),
    (16, 'Token xac thuc het han qua som',
        'Nguoi dung bao bi dang xuat ngoai y muon truoc thoi gian het han cong bo cua token.',
        'high', 'security', 'resolved', 'Nam', 'Binh',
        NOW() - INTERVAL 6 DAY, (NOW() - INTERVAL 6 DAY) + INTERVAL 95 MINUTE, (NOW() - INTERVAL 6 DAY) + INTERVAL 95 MINUTE),
    (17, 'Hang doi xu ly don bi tac nghen',
        'So luong don cho xu ly trong hang doi tang lien tuc, toc do xu ly khong theo kip toc do nhan moi.',
        'critical', 'infra', 'in_progress', 'Hoa', 'Nam',
        NOW() - INTERVAL 2 HOUR, (NOW() - INTERVAL 2 HOUR) + INTERVAL 15 MINUTE, NULL),
    (18, 'Truy van tim kiem cham do chi muc cu',
        'Truy van tim kiem tren bang lich su chay cham dan theo thoi gian, nghi do chi muc khong con phu hop voi du lieu hien tai.',
        'medium', 'database', 'closed', 'Binh', 'Lan',
        NOW() - INTERVAL 20 DAY, (NOW() - INTERVAL 20 DAY) + INTERVAL 420 MINUTE, (NOW() - INTERVAL 20 DAY) + INTERVAL 400 MINUTE);

-- Một dòng 'created' cho MỌI ticket, actor là reporter, mốc thời gian trùng
-- created_at của ticket đó — ticket nào cũng phải có lịch sử "được tạo".
INSERT INTO activities (ticket_id, actor, action, from_value, to_value, created_at) VALUES
    (1, 'Hoa', 'created', NULL, NULL, NOW() - INTERVAL 2 DAY),
    (2, 'Hoa', 'created', NULL, NULL, NOW() - INTERVAL 90 MINUTE),
    (3, 'Binh', 'created', NULL, NULL, NOW() - INTERVAL 6 HOUR),
    (4, 'Lan', 'created', NULL, NULL, NOW() - INTERVAL 3 HOUR),
    (5, 'Nam', 'created', NULL, NULL, NOW() - INTERVAL 5 DAY),
    (6, 'Binh', 'created', NULL, NULL, NOW() - INTERVAL 10 DAY),
    (7, 'Lan', 'created', NULL, NULL, NOW() - INTERVAL 1 DAY),
    (8, 'Nam', 'created', NULL, NULL, NOW() - INTERVAL 4 HOUR),
    (9, 'Hoa', 'created', NULL, NULL, NOW() - INTERVAL 7 DAY),
    (10, 'Binh', 'created', NULL, NULL, NOW() - INTERVAL 12 DAY),
    (11, 'Lan', 'created', NULL, NULL, NOW() - INTERVAL 4 DAY),
    (12, 'Nam', 'created', NULL, NULL, NOW() - INTERVAL 8 HOUR),
    (13, 'Hoa', 'created', NULL, NULL, NOW() - INTERVAL 15 DAY),
    (14, 'Binh', 'created', NULL, NULL, NOW() - INTERVAL 5 HOUR),
    (15, 'Lan', 'created', NULL, NULL, NOW() - INTERVAL 1 DAY),
    (16, 'Nam', 'created', NULL, NULL, NOW() - INTERVAL 6 DAY),
    (17, 'Hoa', 'created', NULL, NULL, NOW() - INTERVAL 2 HOUR),
    (18, 'Binh', 'created', NULL, NULL, NOW() - INTERVAL 20 DAY);

-- Với ticket không còn ở 'open' (13 ticket), thêm một dòng status_changed
-- ghi lai buoc chuyen tu 'open' sang trang thai hien tai, actor la assignee
-- neu co (nguoi xu ly), khong thi la reporter; created_at trung updated_at
-- cua ticket do (thoi diem trang thai duoc cap nhat lan cuoi).
INSERT INTO activities (ticket_id, actor, action, from_value, to_value, created_at) VALUES
    (1, 'Nam', 'status_changed', 'open', 'in_progress', (NOW() - INTERVAL 2 DAY) + INTERVAL 40 MINUTE),
    (3, 'Lan', 'status_changed', 'open', 'in_progress', (NOW() - INTERVAL 6 HOUR) + INTERVAL 25 MINUTE),
    (5, 'Hoa', 'status_changed', 'open', 'resolved', (NOW() - INTERVAL 5 DAY) + INTERVAL 130 MINUTE),
    (6, 'Nam', 'status_changed', 'open', 'closed', (NOW() - INTERVAL 10 DAY) + INTERVAL 340 MINUTE),
    (8, 'Binh', 'status_changed', 'open', 'in_progress', (NOW() - INTERVAL 4 HOUR) + INTERVAL 20 MINUTE),
    (9, 'Lan', 'status_changed', 'open', 'resolved', (NOW() - INTERVAL 7 DAY) + INTERVAL 45 MINUTE),
    (10, 'Hoa', 'status_changed', 'open', 'closed', (NOW() - INTERVAL 12 DAY) + INTERVAL 100 MINUTE),
    (11, 'Nam', 'status_changed', 'open', 'resolved', (NOW() - INTERVAL 4 DAY) + INTERVAL 260 MINUTE),
    (13, 'Lan', 'status_changed', 'open', 'closed', (NOW() - INTERVAL 15 DAY) + INTERVAL 170 MINUTE),
    (15, 'Hoa', 'status_changed', 'open', 'in_progress', (NOW() - INTERVAL 1 DAY) + INTERVAL 30 MINUTE),
    (16, 'Binh', 'status_changed', 'open', 'resolved', (NOW() - INTERVAL 6 DAY) + INTERVAL 95 MINUTE),
    (17, 'Nam', 'status_changed', 'open', 'in_progress', (NOW() - INTERVAL 2 HOUR) + INTERVAL 15 MINUTE),
    (18, 'Lan', 'status_changed', 'open', 'closed', (NOW() - INTERVAL 20 DAY) + INTERVAL 420 MINUTE);

-- Bình luận mẫu cho một vài ticket có nhiều hoạt động nhất — không cần phủ
-- hết 18 ticket, chỉ đủ để demo phần comment trong UI.
INSERT INTO comments (ticket_id, author, body, created_at) VALUES
    (1, 'Nam', 'Da xem lai dashboard, nghi do so luong ket noi dong thoi vuot nguong pool hien tai.',
        (NOW() - INTERVAL 2 DAY) + INTERVAL 15 MINUTE),
    (1, 'Hoa', 'Dang thu tang gioi han pool o moi truong test truoc khi ap dung production.',
        (NOW() - INTERVAL 2 DAY) + INTERVAL 35 MINUTE),
    (2, 'Hoa', 'Da rollback ve ban truoc, dang theo doi ty le loi 502 co giam khong.',
        NOW() - INTERVAL 60 MINUTE),
    (5, 'Hoa', 'Kiem tra thi thay so ket noi toi database vuot gioi han cau hinh vao gio cao diem.',
        (NOW() - INTERVAL 5 DAY) + INTERVAL 60 MINUTE),
    (9, 'Lan', 'Da lien he doi ha tang mang, xac nhan la su co tren duong truyen giua hai khu vuc.',
        (NOW() - INTERVAL 7 DAY) + INTERVAL 20 MINUTE),
    (16, 'Binh', 'Kiem tra cau hinh thoi gian song cua token, thay bi dat sai don vi (giay thay vi phut).',
        (NOW() - INTERVAL 6 DAY) + INTERVAL 50 MINUTE),
    (17, 'Nam', 'Hang doi dang tang do mot tien trinh xu ly bi dung, dang khoi dong lai.',
        (NOW() - INTERVAL 2 HOUR) + INTERVAL 5 MINUTE);
