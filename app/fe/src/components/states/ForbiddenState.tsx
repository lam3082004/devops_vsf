// 403 — IP chưa nằm trong whitelist (PRD mục 4, "An toàn": truy cập chỉ từ IP whitelist). Khác
// ErrorBanner: đây không phải lỗi tạm thời có thể "thử lại", nên không có nút retry.
export function ForbiddenState() {
  return (
    <div
      role="alert"
      className="flex flex-col items-center gap-1 rounded border border-amber-300 bg-amber-50 px-6 py-10 text-center text-sm text-amber-800 dark:border-amber-900 dark:bg-amber-950 dark:text-amber-200"
    >
      <p>IP của bạn chưa được phép truy cập OpsBoard.</p>
    </div>
  );
}
