# Ảnh chụp màn hình

Quy ước lưu ảnh dùng làm bằng chứng. File `evidence/M*.md` trỏ tới ảnh trong `evidence/dXX/screenshots/`.

## Cấu trúc

Mỗi bài một thư mục, ảnh nằm trong `screenshots/` của bài đó (log/JSON thô để ở `evidence/raw/`):

```
evidence/
  d02/screenshots/   ảnh của bài D2
  d19/screenshots/   ảnh của bài D19
  ...
  raw/               log, JSON, TSV thô (mọi bài)
```

Tên file: `<nội dung>-<YYYYMMDD-HHMM>.png`, ví dụ `403-from-lte-20260916-1052.png`. Ảnh dùng làm
bằng chứng must-have thì `evidence/MXX.md` trỏ thẳng tới file trong `dXX/screenshots/`, không copy.

## Trước khi lưu ảnh
- Che hoặc cắt: email cá nhân, mật khẩu, token, connection string.
- IP nhà: nếu repo public thì che 2 octet cuối (`203.0.113.xxx`).
- Subscription ID và tenant ID không phải secret nhưng hạn chế phô ra nếu repo public.

## Lưu ý
Ảnh gửi qua khung chat **không được lưu lại tự động** — bộ nhớ đệm ảnh của phiên bị xoá sau khi phiên kết thúc. Muốn giữ thì tự lưu vào thư mục này ngay khi chụp.
