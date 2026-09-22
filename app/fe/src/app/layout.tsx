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

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="vi"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
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
