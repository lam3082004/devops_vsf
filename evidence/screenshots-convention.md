# Ảnh chụp màn hình

Nơi lưu ảnh dùng làm bằng chứng. File `evidence/M*.md` trỏ tới ảnh trong thư mục này.

## Cấu trúc

Mỗi bài một thư mục:

```
evidence/screenshots/
  d02/  ảnh của bài D2
  d06/  ảnh của bài D6
  m06/  ảnh dùng làm bằng chứng nộp cho M6
  ...
```

Tên file trong thư mục: `<nội dung>-<YYYYMMDD-HHMM>.png`, ví dụ `403-from-lte-20260916-1052.png`.

Thư mục `d01`…`d25` cho ảnh học theo bài; `m01`…`m11` cho ảnh chốt làm bằng chứng nộp (có thể là bản copy của ảnh trong `dXX`).

## Trước khi lưu ảnh
- Che hoặc cắt: email cá nhân, mật khẩu, token, connection string.
- IP nhà: nếu repo public thì che 2 octet cuối (`203.0.113.xxx`).
- Subscription ID và tenant ID không phải secret nhưng hạn chế phô ra nếu repo public.

## Lưu ý
Ảnh gửi qua khung chat **không được lưu lại tự động** — bộ nhớ đệm ảnh của phiên bị xoá sau khi phiên kết thúc. Muốn giữ thì tự lưu vào thư mục này ngay khi chụp.
