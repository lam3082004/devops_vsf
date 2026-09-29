// Sampler của tracing `fe` (src/instrumentation.node.ts) — tách riêng để test được
// (tracing-sampler.test.mjs) và để src/lib/api.ts không kéo SDK vào bundle của nó.
import type { Attributes, Context, SpanKind } from "@opentelemetry/api";
import {
  AlwaysOffSampler,
  AlwaysOnSampler,
  ParentBasedSampler,
  SamplingDecision,
  type Sampler,
  type SamplingResult,
} from "@opentelemetry/sdk-trace-node";

// Probe và poll (health check + warm-up của App Service trỏ vào /api/version,
// scripts/m2-poll.sh) chiếm gần hết lưu lượng mà không mang thông tin trace — bỏ như `be`
// bỏ /health, /version (quyết định E của D20). Asset tĩnh của Next cũng không cần trace.
const UNTRACED_PREFIXES = ["/api/version", "/api/health", "/_next/", "/favicon.ico"];

export function shouldTrace(url: string | undefined): boolean {
  const path = (url ?? "").split("?")[0];
  return !UNTRACED_PREFIXES.some((prefix) => path.startsWith(prefix));
}

// Span gốc: bỏ probe/poll theo path. Next.js gắn `http.target` = req.url lúc TẠO span gốc
// (base-server.js, BaseServerSpan.handleRequest) — sampler chỉ thấy attribute có sẵn lúc đó.
class ProbePathSampler implements Sampler {
  shouldSample(
    _context: Context,
    _traceId: string,
    _spanName: string,
    _spanKind: SpanKind,
    attributes: Attributes
  ): SamplingResult {
    const target = attributes["http.target"] ?? attributes["url.path"];
    const url = typeof target === "string" ? target : undefined;
    return {
      decision: shouldTrace(url)
        ? SamplingDecision.RECORD_AND_SAMPLED
        : SamplingDecision.NOT_RECORD,
    };
  }

  toString(): string {
    return "ProbePathSampler";
  }
}

// Cùng hình với sampler của `be` (app/be/Infrastructure/Telemetry.cs):
// - span gốc hoặc có cha từ xa (traceparent của trình duyệt) → lọc theo path, còn lại 100%,
//   kể cả traceparent cờ "không sample" (-00);
// - span con có cha local → theo cha: cha bị bỏ (probe) thì con cũng bỏ, không thành
//   dependency mồ côi.
export function createFeSampler(): Sampler {
  const byPath = new ProbePathSampler();
  return new ParentBasedSampler({
    root: byPath,
    remoteParentSampled: byPath,
    remoteParentNotSampled: byPath,
    localParentSampled: new AlwaysOnSampler(),
    localParentNotSampled: new AlwaysOffSampler(),
  });
}
