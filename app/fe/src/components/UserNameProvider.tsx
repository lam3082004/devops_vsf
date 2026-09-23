"use client";

import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  useSyncExternalStore,
  type ReactNode,
} from "react";
import { USER_NAME_STORAGE_KEY, isValidUserName } from "@/lib/user-name";

// localStorage là "hệ thống ngoài React" nên đọc bằng useSyncExternalStore thay vì useEffect +
// setState lúc mount — cách cũ gây "cascading render" (React 19.2 lint mới cấm hẳn set-state-in-effect,
// xem https://react.dev/learn/you-might-not-need-an-effect mục "Force update / external sync").
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

function readStoredName(): string | null {
  const stored = window.localStorage.getItem(USER_NAME_STORAGE_KEY);
  return stored && isValidUserName(stored) ? stored : null;
}

// Server không có localStorage — luôn coi như chưa có tên, useSyncExternalStore sẽ tự đồng bộ lại
// đúng giá trị thật ngay sau khi hydrate (không cần effect thủ công).
function getServerSnapshot(): string | null {
  return null;
}

// Cùng một mẹo useSyncExternalStore để biết "đã qua khỏi lần render khớp với server" — tránh render
// hộp nhập tên (NameGate) ngay trên SSR cho MỌI người dùng trước khi kịp đọc localStorage thật.
function subscribeNever() {
  return () => {};
}
const getClientTrue = () => true;
const getServerFalse = () => false;

interface UserNameContextValue {
  userName: string | null;
  // Hộp nhập tên (S1) có mở hay không — NameGate tự đọc giá trị này để render.
  isGateOpen: boolean;
  openGate: () => void;
  closeGate: () => void;
  setUserName: (name: string) => void;
  clearUserName: () => void;
  // Gọi trước mỗi thao tác ghi: có tên → trả true, cho đi tiếp; chưa có tên → tự mở hộp nhập và
  // trả false để nơi gọi dừng thao tác lại (US-01: "chưa có tên thì mọi thao tác ghi bị chặn").
  requireUserName: () => boolean;
}

const UserNameContext = createContext<UserNameContextValue | null>(null);

export function UserNameProvider({ children }: { children: ReactNode }) {
  const userName = useSyncExternalStore(subscribe, readStoredName, getServerSnapshot);
  const isClient = useSyncExternalStore(subscribeNever, getClientTrue, getServerFalse);
  // Mở tay (bấm 👤 để đổi tên) — trạng thái UI thuần, không liên quan localStorage nên vẫn là useState
  // bình thường.
  const [manualOpen, setManualOpen] = useState(false);

  const setUserName = useCallback((name: string) => {
    window.localStorage.setItem(USER_NAME_STORAGE_KEY, name.trim());
    notify();
    setManualOpen(false);
  }, []);

  const clearUserName = useCallback(() => {
    window.localStorage.removeItem(USER_NAME_STORAGE_KEY);
    notify();
  }, []);

  const openGate = useCallback(() => setManualOpen(true), []);

  const closeGate = useCallback(() => {
    // Chỉ cho đóng hộp khi đã có tên hợp lệ rồi (vd bấm "Huỷ" lúc đổi tên) — chưa có tên thì hộp phải
    // ở lại, không cho lách qua bằng cách đóng nó.
    setManualOpen((open) => (userName ? false : open));
  }, [userName]);

  const requireUserName = useCallback(() => {
    if (userName) return true;
    setManualOpen(true);
    return false;
  }, [userName]);

  // Chưa hydrate xong (isClient=false) thì luôn coi như đóng, tránh hộp nhập tên loé ra trên mọi
  // trang trước khi kịp biết localStorage đã có tên hay chưa.
  const isGateOpen = isClient && (manualOpen || userName === null);

  const value = useMemo<UserNameContextValue>(
    () => ({
      userName,
      isGateOpen,
      openGate,
      closeGate,
      setUserName,
      clearUserName,
      requireUserName,
    }),
    [userName, isGateOpen, openGate, closeGate, setUserName, clearUserName, requireUserName]
  );

  return <UserNameContext.Provider value={value}>{children}</UserNameContext.Provider>;
}

export function useUserName(): UserNameContextValue {
  const ctx = useContext(UserNameContext);
  if (!ctx) {
    throw new Error("useUserName phai duoc goi ben trong UserNameProvider");
  }
  return ctx;
}
