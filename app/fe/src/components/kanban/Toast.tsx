"use client";

import { useEffect } from "react";

interface ToastProps {
  message: string;
  onClose: () => void;
}

// Toast nổi báo lỗi khi PATCH status thất bại (409 invalid_transition hoặc lỗi khác) — màu/border
// giống ErrorBanner (components/states/ErrorBanner.tsx) để nhất quán, nhưng `fixed` thay vì tĩnh
// trong luồng trang, và tự ẩn sau vài giây thay vì phải bấm "Thử lại".
export function Toast({ message, onClose }: ToastProps) {
  useEffect(() => {
    const timer = setTimeout(onClose, 5000);
    return () => clearTimeout(timer);
  }, [onClose]);

  return (
    <div
      role="alert"
      className="fixed bottom-4 right-4 z-50 flex max-w-sm items-start gap-3 rounded border border-red-300 bg-red-50 px-4 py-3 text-sm text-red-800 shadow-lg dark:border-red-900 dark:bg-red-950 dark:text-red-200"
    >
      <span>{message}</span>
      <button
        type="button"
        onClick={onClose}
        aria-label="Đóng thông báo"
        className="shrink-0 rounded px-1 font-medium hover:bg-red-100 dark:hover:bg-red-900"
      >
        ✕
      </button>
    </div>
  );
}
