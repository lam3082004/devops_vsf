"use client";

import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from "react";

// Context điều khiển hộp thoại tạo ticket (S4) — mở từ nút "+ Ticket" ở AppHeader, đóng ở CreateTicketDialog
// khi tạo xong hoặc bấm Huỷ. Không cần localStorage như UserNameProvider vì đây chỉ là trạng thái UI
// thuần trong phiên, mất đi khi rời trang là đúng.
interface CreateTicketDialogContextValue {
  isOpen: boolean;
  openDialog: () => void;
  closeDialog: () => void;
}

const CreateTicketDialogContext = createContext<CreateTicketDialogContextValue | null>(null);

export function CreateTicketDialogProvider({ children }: { children: ReactNode }) {
  const [isOpen, setIsOpen] = useState(false);

  const openDialog = useCallback(() => setIsOpen(true), []);
  const closeDialog = useCallback(() => setIsOpen(false), []);

  const value = useMemo<CreateTicketDialogContextValue>(
    () => ({ isOpen, openDialog, closeDialog }),
    [isOpen, openDialog, closeDialog]
  );

  return (
    <CreateTicketDialogContext.Provider value={value}>
      {children}
    </CreateTicketDialogContext.Provider>
  );
}

export function useCreateTicketDialog(): CreateTicketDialogContextValue {
  const ctx = useContext(CreateTicketDialogContext);
  if (!ctx) {
    throw new Error("useCreateTicketDialog phai duoc goi ben trong CreateTicketDialogProvider");
  }
  return ctx;
}
