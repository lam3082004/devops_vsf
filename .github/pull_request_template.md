## Tóm tắt

<!-- Thay đổi gì, vì sao. 2-3 dòng. -->

## AI usage

<!-- Phần nào do AI sinh, bạn đã sửa gì. Nếu AI sinh ra thứ sai → thêm 1 dòng vào ai-failure-log.md và link ở đây. -->

## Bằng chứng

<!-- Lệnh đã chạy + output, link CI run, screenshot. Không có bằng chứng = chưa xong. -->

## Checklist

- [ ] Không có secret trong diff (hook gitleaks đã chạy)
- [ ] `make check` xanh ở local (fmt + clippy + test)
- [ ] Đã cập nhật `notes/` hoặc `evidence/` nếu bài học có bằng chứng mới
- [ ] Resource Azure tạo ra trong lúc làm đã được xoá (`az group list` sạch)
