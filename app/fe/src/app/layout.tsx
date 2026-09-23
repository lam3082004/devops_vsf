import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import { UserNameProvider } from "@/components/UserNameProvider";
import { AppHeader } from "@/components/AppHeader";
import { NameGate } from "@/components/NameGate";
import { CreateTicketDialogProvider } from "@/components/CreateTicketProvider";
import { CreateTicketDialog } from "@/components/CreateTicketDialog";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "OpsBoard",
  description: "Quản lý ticket lỗi và đầu việc cho team vận hành",
};

// Chuỗi JS thuần (không phải TS) vì chạy trong thẻ <script> chèn thẳng bằng dangerouslySetInnerHTML,
// TRƯỚC khi React hydrate — layout.tsx là Server Component nên không đọc được localStorage lúc render
// để chọn class đúng ngay từ đầu; thiếu bước này thì mỗi lần tải trang sẽ nhấp nháy đúng-rồi-sai màu
// (FOUC) khi lựa chọn đã lưu khác với prefers-color-scheme của OS. Logic 3 nhánh (light/dark/system) phải
// khớp tay với applyThemeClass trong ThemeToggle.tsx — lệch nhau là sinh nhấp nháy lại từ đầu.
const THEME_INIT_SCRIPT = `(function () {
  try {
    var stored = localStorage.getItem('opsboard:theme');
    var root = document.documentElement;
    if (stored === 'light') {
      root.classList.add('light');
    } else if (stored === 'dark') {
      root.classList.add('dark');
    } else if (window.matchMedia('(prefers-color-scheme: dark)').matches) {
      root.classList.add('dark');
    }
  } catch (e) {
    // localStorage/matchMedia có thể ném lỗi (private mode, storage bị chặn...) — im lặng bỏ qua, để CSS
    // mặc định (@media prefers-color-scheme trong globals.css) tự quyết định thay vì làm vỡ trang.
  }
})();`;

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="vi"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
      // Script chống FOUC bên dưới có thể gắn class .dark/.light lên đây trước khi React hydrate — nếu
      // không có suppressHydrationWarning, React sẽ so class lúc hydrate với class server render ra (không
      // có .dark/.light) và cảnh báo mismatch dù đây là khác biệt cố ý, không phải lỗi.
      suppressHydrationWarning
    >
      <head>
        <script dangerouslySetInnerHTML={{ __html: THEME_INIT_SCRIPT }} />
      </head>
      <body className="min-h-full flex flex-col">
        <UserNameProvider>
          <CreateTicketDialogProvider>
            <AppHeader />
            <main className="flex-1">{children}</main>
            <NameGate />
            <CreateTicketDialog />
          </CreateTicketDialogProvider>
        </UserNameProvider>
      </body>
    </html>
  );
}
