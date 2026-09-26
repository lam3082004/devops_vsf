// Logic thuần cho route /api/health (D17, quyết định B — notes/d17-prep.md). Tách khỏi
// route handler để test được bằng `node:test` (xem health.test.mjs) mà không cần dựng
// runtime Next.js. QUAN TRỌNG: file này KHÔNG được import "next/server" hay bất cứ gì
// dưới alias "@/..." — test chạy thẳng bằng `node --test`, Node 24 chỉ tự lột (strip)
// type annotation của .ts lúc đọc file, KHÔNG tự resolve alias hay bundle module của Next.
//
// route.ts (cùng thư mục api/health) chỉ gọi hàm này rồi map status -> mã HTTP; mọi quyết
// định (gọi be nào, timeout bao lâu, coi gì là "ok") nằm ở đây để test một chỗ duy nhất.

export interface HealthCheckDeps {
  // process.env.API_BASE_URL — có thể undefined (chưa cấu hình, hoặc build lúc chưa có env).
  apiBaseUrl: string | undefined;
  // Fetch có thể tiêm được để test không gọi mạng thật (Fake theo trạng thái mong muốn).
  fetchImpl: typeof fetch;
  // Mặc định ~3s — đủ để phát hiện `be` chết/treo mà không làm CD chờ lâu mỗi lần poll
  // (CD gọi route này mỗi 5s trong lúc poll, xem cd.yml).
  timeoutMs?: number;
}

export interface HealthCheckResult {
  status: "ok" | "fail";
  // CHỈ hostname của be đã gọi (vd "app-vsf-xxx-staging.azurewebsites.net") — bằng chứng
  // #15 (fe staging thật sự gọi be staging), KHÔNG bao giờ là URL đầy đủ kèm query string
  // hay secret. null khi không tính được host (thiếu API_BASE_URL hoặc URL không hợp lệ).
  beHost: string | null;
  // Mã HTTP be trả về, hoặc null nếu không nhận được response nào (mất mạng, timeout).
  beStatus: number | null;
}

export async function checkBackendHealth({
  apiBaseUrl,
  fetchImpl,
  timeoutMs = 3000,
}: HealthCheckDeps): Promise<HealthCheckResult> {
  if (!apiBaseUrl) {
    // Thiếu cấu hình = fail. Không gọi fetch — không có gì để gọi.
    return { status: "fail", beHost: null, beStatus: null };
  }

  let target: URL;
  try {
    target = new URL("/health", apiBaseUrl);
  } catch {
    // API_BASE_URL méo (không parse được thành URL) — coi như chưa cấu hình đúng.
    return { status: "fail", beHost: null, beStatus: null };
  }
  const beHost = target.host;

  try {
    const res = await fetchImpl(target, {
      cache: "no-store",
      signal: AbortSignal.timeout(timeoutMs),
    });
    return { status: res.status === 200 ? "ok" : "fail", beHost, beStatus: res.status };
  } catch {
    // Mất mạng, timeout, be sập kết nối giữa chừng... — mọi lỗi fetch đều fail, kèm
    // host ĐÃ THỬ gọi (tính được trước khi fetch chạy) để log/CD biết đang trỏ đi đâu.
    return { status: "fail", beHost, beStatus: null };
  }
}
