# D10 — GATE: destroy → apply không thao tác tay

**Cần:** D9 · **Chi phí:** có, tính theo giờ khi môi trường bật · **Bằng chứng:** `evidence/M8.md`

> Đề: "Không dựng lại được hạ tầng bằng Terraform và không giải thích được state / lock / dependency → dừng hoặc đổi scope. Không kéo dài để cho qua."

## 1. Tiền kiểm
- [ ] Mọi code Terraform đã merge vào `main` qua PR (không có thay đổi local chưa commit).
- [ ] Làm việc từ **bản clone mới** của `main` (chứng minh không phụ thuộc file lạ trên máy).
- [ ] Không còn resource tạo tay trong `rg-vsf-dev` (nếu có — đó là lỗi cần sửa, không phải xoá lặng lẽ).

## 2. Chạy và ghi log thô
Ghi **toàn bộ output kèm thời gian** ra file trong `evidence/raw/` (dùng công cụ ghi log của shell, không chép tay):

1. `make down` → log `m8-destroy-<ngày>.log`
2. Portal: `rg-vsf-dev` không tồn tại · Key Vault không nằm trong **Deleted vaults** (đã purge) · chụp.
3. `make up` → log `m8-apply-<ngày>.log`
4. Kiểm tra sau apply:

   | Kiểm tra | Kết quả |
   |---|---|
   | URL app trả 200 (placeholder) | |
   | ACR admin disabled | |
   | KV có secret, RBAC mode | |
   | Firewall MySQL = số possible outbound IPs | |
   | Slot staging có identity | |
   | `plan` ngay sau apply → No changes | |

5. `make down` lần nữa (không để qua đêm).

## 3. Nếu lỗi — sửa trong code, không sửa tay

| Lỗi thường gặp | Nguyên nhân | Hướng sửa trong code |
|---|---|---|
| Vault name already exists | soft-deleted vault chưa purge | feature purge on destroy, không bật purge protection |
| 403 khi tạo secret / pull image | RBAC chưa lan truyền | phụ thuộc tường minh + chờ, hoặc retry trong Makefile |
| Invalid for_each | outbound IPs chưa biết | apply 2 pha (D8) |
| MissingSubscriptionRegistration | provider chưa register | register trong bootstrap / ghi prereq README |
| Name already taken | tên toàn cầu trùng | hậu tố ngẫu nhiên |
| State locked | lần chạy trước bị ngắt | kiểm tra lease, chỉ force-unlock khi chắc chắn |

Mỗi lỗi gặp → 1 dòng `known-issues.md` (đã sửa thế nào) → chạy lại **từ đầu** (destroy → apply), không chạy tiếp từ giữa.

## 4. `evidence/M8.md`
```
# M8 — Terraform toàn bộ hạ tầng
Ngày · commit SHA của main
Lệnh: make down → make up (không thao tác tay giữa hai lệnh)
Log: evidence/raw/m8-destroy-….log, evidence/raw/m8-apply-….log
Thời gian: destroy … phút · apply … phút
Bảng kiểm tra sau apply (mục 2.4)
Ngoại lệ có chủ đích: infra/bootstrap (lý do)
Lỗi gặp và cách sửa (link known-issues)
```

## 5. Chuẩn bị trả lời mentor (tự nói, không đọc)

| Câu hỏi | Ý chính phải có |
|---|---|
| State là gì? Mất state thì sao? | ánh xạ code ↔ resource thật; mất → Terraform tưởng chưa có gì, cố tạo trùng; khôi phục bằng versioning blob / import |
| Lock là gì? Hiện thực trên Azure ra sao? | chống 2 lần ghi đồng thời; blob lease; thí nghiệm D7 |
| Dependency ngầm vs tường minh? Ví dụ trong repo | tham chiếu thuộc tính; `depends_on` cho secret chờ role |
| Vì sao bootstrap tách riêng? | vòng đời; không destroy nơi chứa state của chính mình |
| Vì sao apply 2 pha? | giá trị chưa biết lúc plan + for_each |
| Terraform và CD cùng sửa Web App thì sao? | ignore_changes image; phân chia sở hữu thuộc tính |
| Secret nằm ở đâu trong state? | random_password, secret KV — state phải được bảo vệ |

## Xong khi
- [ ] 2 log thô · [ ] bảng kiểm tra đầy đủ · [ ] `evidence/M8.md` · [ ] trả lời trôi 7 câu · [ ] resource đã `down`
