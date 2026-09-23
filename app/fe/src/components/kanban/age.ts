// Hàm thuần tính "tuổi" ticket từ created_at tới hiện tại, định dạng ngắn kiểu "2h"/"5h"/"1d"/"3d"
// (wire-frame.md, mục S2). Tách khỏi TicketCard để dễ test độc lập sau này nếu cần.
export function formatTicketAge(createdAt: string): string {
  const createdMs = new Date(createdAt).getTime();
  const diffMs = Math.max(0, Date.now() - createdMs);
  const diffHours = Math.floor(diffMs / (60 * 60 * 1000));
  if (diffHours < 24) return `${diffHours}h`;
  const diffDays = Math.floor(diffHours / 24);
  return `${diffDays}d`;
}
