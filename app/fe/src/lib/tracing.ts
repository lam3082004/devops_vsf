// Nối trace fe → be (D21, tracing `fe`). Tách khỏi src/lib/api.ts để test được mà không
// cần `next/server` (tracing.test.mjs).
import { context, propagation } from "@opentelemetry/api";

// Khi telemetry bật (src/instrumentation.node.ts), span đang chạy của `fe` — con của
// traceparent trình duyệt gửi lên, nếu có — là cha của request sang `be` → App Insights nối
// được trình duyệt → fe → be thành một cây. fetch của Next.js không tự gắn header này.
// Telemetry tắt thì propagator là no-op, trả undefined → nơi gọi giữ cách cũ: chuyển tiếp
// nguyên traceparent của trình duyệt.
export function currentTraceparent(): string | undefined {
  const carrier: Record<string, string> = {};
  propagation.inject(context.active(), carrier);
  return carrier.traceparent;
}
