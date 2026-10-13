"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useUserName } from "@/components/UserNameProvider";
import { useCreateTicketDialog } from "@/components/CreateTicketProvider";
import { ThemeToggle } from "@/components/ThemeToggle";

// Điều hướng chung (wire-frame.md, mục "Điều hướng chung"). Board/Danh sách/Thống kê là trang của
// FE-2/FE-3/FE-5 — chưa tồn tại ở FE-1, nav chỉ dựng khung liên kết trước.
const NAV_LINKS = [
  { href: "/", label: "Bảng" },
  { href: "/tickets", label: "Danh sách" },
  { href: "/stats", label: "Thống kê" },
] as const;

export function AppHeader() {
  const pathname = usePathname();
  const { userName, requireUserName, openGate } = useUserName();
  const { openDialog } = useCreateTicketDialog();

  return (
    <header className="flex items-center justify-between border-b border-zinc-200 px-6 py-3 dark:border-zinc-800">
      <div className="flex items-center gap-6">
        <span className="font-semibold">OpsBoard123</span>
        <nav className="flex gap-4 text-sm">
          {NAV_LINKS.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              className={
                pathname === link.href
                  ? "font-medium text-zinc-950 dark:text-white"
                  : "text-zinc-500 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-zinc-100"
              }
            >
              {link.label}
            </Link>
          ))}
        </nav>
      </div>
      <div className="flex items-center gap-3">
        <button
          type="button"
          // Có tên rồi mới mở hộp tạo ticket (US-01: chưa có tên thì mọi thao tác ghi bị chặn) —
          // requireUserName() tự mở hộp nhập tên khi chưa có, trả false để không mở luôn hộp tạo ticket.
          onClick={() => {
            if (requireUserName()) openDialog();
          }}
          className="rounded bg-zinc-900 px-3 py-1.5 text-sm font-medium text-white hover:bg-zinc-700 dark:bg-white dark:text-zinc-900"
        >
          + Tạo ticket
        </button>
        <button
          type="button"
          onClick={openGate}
          className="text-sm text-zinc-600 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-zinc-100"
        >
          👤 {userName ?? "Chưa đặt tên"}
        </button>
        <ThemeToggle />
      </div>
    </header>
  );
}
