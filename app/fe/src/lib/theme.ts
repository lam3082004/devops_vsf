// Hằng số + hàm thuần cho lựa chọn giao diện (Sáng/Tối/Theo hệ thống). Tách khỏi ThemeToggle vì khoá
// localStorage này còn phải khớp tay với script chống FOUC trong layout.tsx (script đó là chuỗi JS
// thuần, không import được module TS) — để 2 nơi lệch nhau là sinh ra nhấp nháy sai màu lúc tải trang.
export const THEME_STORAGE_KEY = "opsboard:theme";

export type ThemeChoice = "light" | "dark" | "system";

const THEME_VALUES: readonly ThemeChoice[] = ["light", "dark", "system"];

export function isThemeChoice(value: string | null): value is ThemeChoice {
  return value !== null && (THEME_VALUES as readonly string[]).includes(value);
}
