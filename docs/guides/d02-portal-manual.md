# D2 — Deploy tay bằng Portal

**Cần:** D1 · **Chi phí:** ~$0.12/giờ khi đang bật (P0V3 + B1ms) · **Nhật ký:** `notes/d2.md`

## Mục tiêu

Tự tay dựng bản thu nhỏ của kiến trúc cuối (Web App + MySQL), rồi đi tìm những thứ Terraform sau này phải khai báo: outbound IPs, firewall, access restrictions, deployment slots, scale out.

> Tạo **MySQL trước** (mất 5–15 phút), trong lúc chờ làm Web App. **Cuối buổi xoá resource group.**

## 1. Resource group
1. `Resource groups` → **+ Create** → Name `rg-d2-manual` · Region **Southeast Asia** → **Review + create** → **Create**.
2. Ghi giờ tạo vào note.

## 2. MySQL Flexible Server
1. `Azure Database for MySQL flexible servers` → **+ Create** → **Flexible server**.
2. **Basics**

   | Ô | Điền |
   |---|---|
   | Resource group | `rg-d2-manual` |
   | Server name | `mysql-d2-<hậu tố>` |
   | Region | Southeast Asia |
   | Availability zone | No preference |
   | Workload type | **Dev/Test** (chọn trước — nó tự đổi cấu hình) |
   | Compute + storage | Burstable **B1ms**, **20 GiB** |
   | Authentication method | **MySQL authentication only** |
   | Administrator login | `d2admin` |
   | Password | tự đặt — **không ghi vào note, không dán vào chat** |

3. **Networking**: Public access (allowed IP addresses) · ❌ **không tick** "Allow public access from any Azure service within Azure" · bấm **+ Add current client IP address**.
4. **Review + create** → **Create**.

## 3. Web App (container mẫu)
1. `App Services` → **+ Create** → **Web App**.
2. **Basics**: RG `rg-d2-manual` · Name `app-d2-<hậu tố>` · Secure unique default hostname **On** · Publish **Container** · OS **Linux** · Region Southeast Asia · Linux Plan **Create new** `asp-d2-manual` · Pricing plan **Premium V3 P0V3**.
3. **Container**: Image source **Quickstart** · chọn sample có sẵn.
4. **Networking**: public access **On**. **Monitoring + secure**: Application Insights **No**.
5. **Review + create** → **Create** → **Go to resource** → bấm **Default domain** → thấy trang mẫu ✅.

## 4. Outbound IPs
Web App → **Settings → Properties** → ghi **Outbound IP addresses** (đang dùng) và **Additional/Possible outbound IP addresses** (có thể dùng). Đếm số IP mỗi ô.

## 5. Firewall MySQL
MySQL → **Settings → Networking** → Firewall rules: đã có IP máy bạn. Thêm tay **2** IP outbound của App Service (Start = End = IP) → **Save**. Nhận xét: nhiều IP thế này thì tự động hoá thế nào?

## 6. Kết nối MySQL từ máy
- **MySQL Workbench / DBeaver**: Host = Server name ở Overview · Port 3306 · User `d2admin` · **SSL: Require**. Tạo DB `d2test`, một bảng nhỏ, thêm và đọc 1 dòng.
- Không cài được: MySQL → **Settings → Databases → + Add** (chỉ chứng minh control plane — ghi rõ trong note).

| Lỗi | Nguyên nhân |
|---|---|
| Timeout | IP máy đã đổi → thêm lại IP |
| SSL connection is required | chưa bật SSL |
| Access denied | sai user/password |

## 7. Chặn IP cho Web App
1. Tra IP máy ("what is my ip").
2. Web App → **Settings → Networking → Inbound traffic configuration → Public network access** → **Enabled from select virtual networks and IP addresses** · Unmatched rule action **Deny** · **+ Add**: `allow-my-ip`, Allow, Priority 100, IPv4 `<IP>/32` → **Save**.
3. Xem tab **Advanced tool site** (SCM/Kudu): luật riêng hay "Use main site rules"?
4. Máy tính → 200 ✅. Điện thoại **4G** → **403** ❌. Chụp cả hai.

## 8. Deployment slot và swap
1. Web App → **Deployment → Deployment slots → + Add slot** → `staging` · Clone settings from production.
2. Mở URL slot staging bằng **điện thoại 4G** → vào được không? (mỗi slot có luật chặn IP riêng)
3. **Swap**: source staging → target production → đọc **Config changes** → **Start Swap**.

## 9. Scale out thủ công
Web App → **Settings → Scale out (App Service plan)** → **Manual** → 2 → **Save** (tiền ×2) → xem qua **Rules Based / Custom autoscale** (chỉ xem) → về **1** → **Save**.

## 10. Hạ tier khi đang có slot
Web App → **Settings → Scale up (App Service plan)** → **Basic B1** → quan sát cảnh báo/lỗi về slot. Chụp lại.

## 11. Dọn dẹp ❗
`rg-d2-manual` → **Delete resource group** → gõ tên → **Delete** → chờ xong → Subscription → **Resources** trống. Ghi giờ xoá.

## Bẫy
- Tick "Allow Azure services" cho MySQL = mở cho Azure của mọi khách hàng.
- Stop Web App **không** dừng tiền — tiền nằm ở plan.
- Luật chặn IP áp riêng cho production, từng slot và site SCM.
- Nhớ xoá RG: MySQL tính tiền kể cả khi bạn không dùng.

## Tự kiểm tra
1. Vì sao firewall MySQL phải dựa trên danh sách *possible* outbound IPs?
2. Tiền nằm ở plan hay app?
3. Vì sao URL staging có thể vẫn vào được từ 4G?
4. Vì sao không hạ được xuống B1 khi có slot?
5. Liệt kê những gì Portal tự làm hộ bạn (đầu vào cho D3).

## Xong khi
- [ ] URL trả 200 · [ ] kết nối MySQL (hoặc ghi rõ chỉ control plane) · [ ] 403 từ 4G · [ ] swap xong · [ ] RG đã xoá, Resources trống
