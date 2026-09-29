// Distributed tracing của `fe` gửi sang Application Insights — chặng fe → be của trace
// end-to-end (D21, quyết định F = a). Cùng cách làm với `be` (app/be/Infrastructure/Telemetry.cs):
// chỉ bật khi có APPLICATIONINSIGHTS_CONNECTION_STRING (local, CI, test không có biến này);
// tham chiếu Key Vault chưa resolve thì tắt và cảnh báo, không làm sập app.
//
// Chỉ exporter + SDK trace, KHÔNG dùng distro @azure/monitor-opentelemetry (thử 29/09, ghi ở
// notes/d21.md): distro không nhận sampler tự viết (chỉ qua biến môi trường), và
// HttpInstrumentation của nó không hook được vì Next nạp module `http` trước register() —
// probe /api/version vẫn bị trace. Span của Next.js tự tạo (request, render, fetch) là đủ.
import { AzureMonitorTraceExporter } from "@azure/monitor-opentelemetry-exporter";
import { resourceFromAttributes } from "@opentelemetry/resources";
import { BatchSpanProcessor, NodeTracerProvider } from "@opentelemetry/sdk-trace-node";

import { createFeSampler } from "@/lib/tracing-sampler";

function log(level: "info" | "warn", event: string, message: string) {
  // 1 dòng JSON/record, cùng tên field với `be` (app/be/Infrastructure/JsonConsoleLogger.cs) —
  // App Service đưa stdout vào AppServiceConsoleLogs, KQL đọc chung một kiểu.
  console.log(JSON.stringify({ time: new Date().toISOString(), level, event, message }));
}

const connectionString = process.env.APPLICATIONINSIGHTS_CONNECTION_STRING;

if (!connectionString) {
  log("info", "telemetry_disabled", "khong co connection string, tat telemetry");
} else if (connectionString.startsWith("@Microsoft.KeyVault(")) {
  log(
    "warn",
    "telemetry_unresolved",
    "APPLICATIONINSIGHTS_CONNECTION_STRING van la tham chieu Key Vault chua resolve, tat telemetry"
  );
} else {
  const provider = new NodeTracerProvider({
    // Role name trong App Insights = tên site, cùng quy ước với `be` (resource detector của
    // distro .NET đặt `app-vsf-<suffix>`). Slot staging cũng mang tên site chính.
    resource: resourceFromAttributes({
      "service.name": process.env.WEBSITE_SITE_NAME ?? "fe",
    }),
    sampler: createFeSampler(),
    spanProcessors: [
      new BatchSpanProcessor(
        new AzureMonitorTraceExporter({
          connectionString,
          // Filesystem container mất theo mỗi lần restart/swap — không ghi hàng đợi xuống đĩa.
          disableOfflineStorage: true,
        })
      ),
    ],
  });
  // Đăng ký provider toàn cục + context manager AsyncLocalStorage + propagator W3C
  // (traceparent) — span của Next.js và currentTraceparent() (src/lib/tracing.ts) dùng chung.
  provider.register();
  log("info", "telemetry_enabled", "bat telemetry Azure Monitor");
}
