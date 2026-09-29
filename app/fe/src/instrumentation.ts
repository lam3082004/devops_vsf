// Next.js gọi register() một lần lúc server khởi động (docs: guides/open-telemetry.md).
// SDK OpenTelemetry chỉ chạy trên runtime Node — import động để bundle edge không kéo nó vào.
export async function register() {
  if (process.env.NEXT_RUNTIME === "nodejs") {
    await import("./instrumentation.node");
  }
}
