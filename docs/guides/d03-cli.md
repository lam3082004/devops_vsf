# D3 — Làm lại D2 bằng Azure CLI

**Cần:** D2 · **Chi phí:** có, tính theo giờ khi môi trường bật · **Nhật ký:** `notes/d3-cli.md` · **AI-OFF:** tự tra docs, không nhờ AI viết lệnh

## Mục tiêu

Dựng lại đúng những gì D2 làm, chỉ bằng dòng lệnh. Mục đích không phải thuộc lệnh, mà là **thấy mọi tham số Portal đã điền ngầm** — đó chính là danh sách Terraform phải khai báo ở D8.

## Chuẩn bị
1. Cài Azure CLI theo trang chính thức "Install the Azure CLI on Linux" (learn.microsoft.com). Kiểm tra phiên bản.
2. Đăng nhập tương tác. Tenant trường có thể yêu cầu chỉ định tenant hoặc dùng device code — đọc mục "Sign in with Azure CLI".
3. Kiểm tra CLI đang trỏ đúng **Azure subscription 1**; nếu không, đặt subscription mặc định.
4. Mở file `notes/d3-cli.md`, chia các mục như bảng dưới.

## Cách tra lệnh (không cần AI)
- Trang tham chiếu mỗi nhóm lệnh trên learn.microsoft.com: tìm "az group", "az mysql flexible-server", "az appservice plan", "az webapp", "az webapp config access-restriction", "az webapp deployment slot".
- Mỗi lệnh đều có phần trợ giúp tích hợp kèm ví dụ.
- Đầu ra: học cách chọn định dạng bảng và lọc trường bằng truy vấn JMESPath (mục "Query Azure CLI command output").

## Các bước

Với **mỗi bước**, ghi vào note: lệnh bạn chạy · từng tham số nghĩa là gì · tham số nào D2 Portal đã tự điền.

| # | Việc | Kết quả mong đợi | Chú ý |
|---|---|---|---|
| 1 | Tạo RG `rg-d3-cli` ở Southeast Asia | RG tồn tại | Region là tham số bắt buộc |
| 2 | Tạo MySQL Flexible B1ms, 20 GiB, public access, firewall chỉ IP máy bạn | Server Ready | **Không đưa mật khẩu thẳng vào dòng lệnh** — nó vào lịch sử shell. Dùng biến môi trường nhập từ prompt ẩn, hoặc để CLI hỏi |
| 3 | Tạo App Service Plan Linux P0V3 | Plan tồn tại | Tham số "is Linux" — Portal tự chọn khi bạn bấm Linux |
| 4 | Tạo Web App dùng image mẫu công khai | URL trả 200 | Tìm cách đặt image container khi tạo app |
| 5 | Lấy danh sách outbound IPs và possible outbound IPs | In ra dạng bảng | Luyện truy vấn trường |
| 6 | Thêm firewall rule MySQL cho từng possible outbound IP | Mỗi IP một rule | Viết một vòng lặp shell đơn giản — cảm nhận vì sao cần `for_each` |
| 7 | Access restriction: allow IP mình, mặc định deny | 4G → 403 | Nhớ phần SCM |
| 8 | Tạo slot `staging`, swap | Swap thành công | |
| 9 | Scale out 2 → 1 | Số instance đổi | |
| 10 | Xoá RG | Resources trống | Có tuỳ chọn không chờ — hiểu hệ quả |

## Thí nghiệm idempotency (15 phút, quan trọng cho GATE)
1. Chạy **lại** lệnh tạo RG, tạo plan, tạo firewall rule lần thứ hai. Ghi lại: lệnh nào báo lỗi "đã tồn tại", lệnh nào lặng lẽ cập nhật, lệnh nào tạo trùng?
2. Sửa tay một cấu hình trên Portal (ví dụ đổi một app setting) → CLI có biết không?
3. Viết 3–5 dòng: "Nếu phải chạy script này mỗi sáng thì vấn đề là…" → đây là lý do Terraform có **state** và **plan**.

## Danh sách "Portal làm ngầm" (điền cuối bài)
Gợi ý các mục thường gặp — tự kiểm chứng cái nào đúng với bạn:
- register resource provider
- chọn SKU/tier mặc định, phiên bản MySQL mặc định, backup retention mặc định
- tạo plan cùng lúc với app
- thêm IP client vào firewall
- tên hostname ngẫu nhiên, HTTPS only, TLS tối thiểu
- clone setting khi tạo slot
- bật/tắt Application Insights

## Bẫy
- Mật khẩu trong lịch sử shell / file note — kiểm tra lại trước khi lưu note.
- CLI mặc định đúng subscription? Tạo nhầm sang subscription khác là tốn tiền ở chỗ không ai theo dõi.
- Tạo MySQL qua CLI có thể hỏi tương tác (ví dụ cho phép IP) — đọc kỹ câu hỏi, đừng Enter bừa.
- Quên xoá RG.

## Tự kiểm tra
1. Portal, CLI, Terraform giống nhau ở điểm nào?
2. Vì sao chạy lại script CLI thường lỗi, còn `terraform apply` lần hai thì "No changes"?
3. Tham số nào của MySQL nếu để mặc định sẽ tốn tiền hơn cần thiết?

## Xong khi
- [ ] `notes/d3-cli.md` có đủ 10 bước kèm giải thích tham số · [ ] kết quả thí nghiệm idempotency · [ ] danh sách "Portal làm ngầm" · [ ] RG đã xoá
