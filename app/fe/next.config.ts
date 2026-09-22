import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Đóng gói tối giản cho Docker (D11+): chỉ copy .next/standalone vào image runtime.
  output: "standalone",
};

export default nextConfig;
