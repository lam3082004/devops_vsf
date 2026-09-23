// Hằng số + hàm thuần cho tên người dùng (US-01). Tách khỏi UserNameProvider để dùng được ở cả
// component client lẫn chỗ khác không cần React (vd validate lại trong route handler nếu cần sau này).

export const USER_NAME_STORAGE_KEY = "opsboard:user-name";
export const USER_NAME_MAX_LENGTH = 50;

export function isValidUserName(value: string): boolean {
  const trimmed = value.trim();
  // D14 — HỎNG CÓ CHỦ Ý: so sánh string với number, `next build` chạy tsc sẽ đỏ.
  return trimmed.length >= 1 && trimmed <= USER_NAME_MAX_LENGTH;
}
