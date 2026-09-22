// Hàm thuần định dạng thời gian hiển thị trong trang chi tiết ticket (S5) — tách khỏi component để dễ
// test độc lập, cùng kiểu với kanban/age.ts. Không cần format phức tạp (wire-frame.md chỉ cần "giờ:phút"
// cho bình luận, ngày+giờ ngắn cho lịch sử/ngày tạo).
export function formatDateTime(iso: string): string {
  return new Date(iso).toLocaleString("vi-VN", { dateStyle: "short", timeStyle: "short" });
}

export function formatTime(iso: string): string {
  return new Date(iso).toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit" });
}
