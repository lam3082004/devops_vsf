"use client";

import { useCallback, useEffect } from "react";
import { useSyncExternalStore } from "react";
import { THEME_STORAGE_KEY, isThemeChoice, type ThemeChoice } from "@/lib/theme";

// localStorage là "hệ thống ngoài React" nên đọc bằng useSyncExternalStore thay vì useEffect + setState
// lúc mount — cùng lý do/mẹo đã dùng ở UserNameProvider (tránh vi phạm rule react-hooks/set-state-in-effect
// của eslint-config-next 16.3.5, và tránh mismatch hydrate vì server không có localStorage).
type Listener = () => void;
let listeners: Listener[] = [];

function subscribe(listener: Listener) {
  listeners.push(listener);
  return () => {
    listeners = listeners.filter((l) => l !== listener);
  };
}

function notify() {
  for (const listener of listeners) listener();
}

function readStoredTheme(): ThemeChoice {
  const stored = window.localStorage.getItem(THEME_STORAGE_KEY);
  return isThemeChoice(stored) ? stored : "system";
}

// Server không có localStorage — luôn trả "system" (đúng bằng mặc định thật của app). Script chống FOUC
// trong layout.tsx đã tô đúng class trước khi React hydrate nên không có nhấp nháy màu nền/chữ; label nút
// có thể lệch 1 frame đầu (giống isClient-trick của UserNameProvider), chấp nhận được vì không ảnh hưởng màu trang.
function getServerSnapshot(): ThemeChoice {
  return "system";
}

function applyThemeClass(theme: ThemeChoice, systemPrefersDark: boolean) {
  const root = document.documentElement;
  if (theme === "light") {
    // .light dùng để CHẶN HẲN khối @media (prefers-color-scheme: dark) trong globals.css — nếu không có
    // class này, chọn "Sáng" thủ công lúc OS đang tối vẫn bị media query ghi đè ngược lại thành tối.
    root.classList.remove("dark");
    root.classList.add("light");
  } else if (theme === "dark") {
    root.classList.add("dark");
    root.classList.remove("light");
  } else {
    // "system": biến CSS (--background/--foreground) đã tự đổi đúng qua khối @media, không cần JS.
    // Nhưng @custom-variant dark trong globals.css đã chuyển toàn bộ class `dark:...` (dùng khắp app,
    // vd AppHeader) sang selector-based theo .dark — nếu không đồng bộ .dark theo đúng OS ở đây thì các
    // class dark: đó im re dù OS đang tối. Vẫn KHÔNG đụng .light ở nhánh này để khối @media được toàn
    // quyền quyết định (không "cố định" giá trị, chỉ phản chiếu OS hiện tại).
    root.classList.remove("light");
    root.classList.toggle("dark", systemPrefersDark);
  }
}

const THEME_SEQUENCE: readonly ThemeChoice[] = ["light", "dark", "system"];
const THEME_LABEL: Record<ThemeChoice, string> = {
  light: "Sáng",
  dark: "Tối",
  system: "Theo hệ thống",
};

export function ThemeToggle() {
  const theme = useSyncExternalStore(subscribe, readStoredTheme, getServerSnapshot);

  // Effect chỉ làm side-effect lên DOM (class trên <html>) + lắng nghe OS đổi prefers-color-scheme khi
  // đang ở "system" — KHÔNG setState trong effect (đó là điều rule react-hooks/set-state-in-effect cấm);
  // `theme` đã tới từ useSyncExternalStore ở trên rồi, effect ở đây chỉ phản chiếu nó ra DOM thật.
  useEffect(() => {
    const media = window.matchMedia("(prefers-color-scheme: dark)");
    applyThemeClass(theme, media.matches);

    if (theme !== "system") return;
    // Chỉ cần nghe sự kiện đổi OS khi đang ở "system" — 2 chế độ thủ công không phụ thuộc OS nên không
    // cần listener, tự dọn dẹp khi theme đổi hoặc unmount.
    const onChange = () => applyThemeClass(theme, media.matches);
    media.addEventListener("change", onChange);
    return () => media.removeEventListener("change", onChange);
  }, [theme]);

  const setTheme = useCallback((next: ThemeChoice) => {
    window.localStorage.setItem(THEME_STORAGE_KEY, next);
    notify();
  }, []);

  const cycleTheme = useCallback(() => {
    const currentIndex = THEME_SEQUENCE.indexOf(theme);
    const next = THEME_SEQUENCE[(currentIndex + 1) % THEME_SEQUENCE.length];
    setTheme(next);
  }, [theme, setTheme]);

  return (
    <button
      type="button"
      onClick={cycleTheme}
      // aria-label nói rõ trạng thái đang chọn + hành động, vì nội dung nút chỉ hiện nhãn hiện tại
      // (xoay vòng qua 3 trạng thái, không phải menu chọn trực tiếp).
      aria-label={`Giao diện: ${THEME_LABEL[theme]}. Bấm để đổi.`}
      title="Đổi giao diện: Sáng / Tối / Theo hệ thống"
      className="rounded border border-zinc-300 px-2.5 py-1.5 text-sm text-zinc-600 hover:text-zinc-900 dark:border-zinc-700 dark:text-zinc-400 dark:hover:text-zinc-100"
    >
      {THEME_LABEL[theme]}
    </button>
  );
}
