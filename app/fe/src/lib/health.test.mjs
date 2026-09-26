// Test cho src/lib/health.ts — bắt đầu đóng known-issues.md #16 ("app/fe có 0 test tự
// động"). Chạy bằng test runner có sẵn của Node (node:test + node:assert), KHÔNG thêm
// dependency mới (không vitest/jest — CLAUDE.md "No new dependency").
//
// File này là .mjs THUẦN (không phải .ts): import thẳng "./health.ts" — Node 24 tự lột
// type annotation của .ts lúc đọc file, không cần biên dịch trước. Cố tình để test là
// .mjs (không phải .test.ts) để KHÔNG lọt vào "include": ["**/*.ts", ...] của tsconfig.json
// — nếu là .test.ts thì `next build` (chạy tsc qua next lint/type-check) sẽ cố biên dịch
// nó vào cây type-check của app, không cần thiết và không đúng vai trò (test không phải
// code Next.js). package.json script "test" gọi thẳng `node --test` trên file .mjs này.
import { test } from "node:test";
import assert from "node:assert/strict";
import { checkBackendHealth } from "./health.ts";

function fakeFetchWithStatus(status) {
  return async () => new Response(null, { status });
}

test("be tra 200 -> ok, beStatus 200", async () => {
  const result = await checkBackendHealth({
    apiBaseUrl: "https://app-vsf-jcip0s-staging.azurewebsites.net",
    fetchImpl: fakeFetchWithStatus(200),
  });
  assert.equal(result.status, "ok");
  assert.equal(result.beStatus, 200);
  assert.equal(result.beHost, "app-vsf-jcip0s-staging.azurewebsites.net");
});

test("be tra 503 -> fail, beStatus 503 (DB loi khong duoc coi la san sang)", async () => {
  const result = await checkBackendHealth({
    apiBaseUrl: "https://app-vsf-jcip0s.azurewebsites.net",
    fetchImpl: fakeFetchWithStatus(503),
  });
  assert.equal(result.status, "fail");
  assert.equal(result.beStatus, 503);
});

test("fetch nem loi (mat mang/timeout) -> fail, beStatus null nhung van biet host da goi", async () => {
  const result = await checkBackendHealth({
    apiBaseUrl: "https://app-vsf-jcip0s.azurewebsites.net",
    fetchImpl: async () => {
      throw new Error("timeout");
    },
  });
  assert.equal(result.status, "fail");
  assert.equal(result.beStatus, null);
  // beHost tinh TRUOC luc goi fetch nen van co du fetch loi — CD can biet no da nham
  // dung host nao du lan goi that bai, khong chi luc thanh cong.
  assert.equal(result.beHost, "app-vsf-jcip0s.azurewebsites.net");
});

test("timeout thuc su (AbortSignal.timeout) cung roi vao nhanh loi -> fail", async () => {
  const result = await checkBackendHealth({
    apiBaseUrl: "https://app-vsf-jcip0s.azurewebsites.net",
    // fetch "cham" hon timeoutMs — mo phong be treo khong tra loi.
    fetchImpl: (_url, init) =>
      new Promise((_resolve, reject) => {
        const signal = init && init.signal;
        if (signal) {
          signal.addEventListener("abort", () => reject(new Error("aborted")));
        }
      }),
    timeoutMs: 10,
  });
  assert.equal(result.status, "fail");
  assert.equal(result.beStatus, null);
});

test("thieu API_BASE_URL -> fail, khong co host/status, khong goi fetch", async () => {
  let fetchCalled = false;
  const result = await checkBackendHealth({
    apiBaseUrl: undefined,
    fetchImpl: async () => {
      fetchCalled = true;
      return new Response(null, { status: 200 });
    },
  });
  assert.equal(result.status, "fail");
  assert.equal(result.beHost, null);
  assert.equal(result.beStatus, null);
  assert.equal(fetchCalled, false);
});

test("body chi co hostname — khong keo theo path/query string cua API_BASE_URL", async () => {
  const result = await checkBackendHealth({
    apiBaseUrl: "https://app-vsf-jcip0s.azurewebsites.net",
    fetchImpl: fakeFetchWithStatus(200),
  });
  assert.equal(result.beHost, "app-vsf-jcip0s.azurewebsites.net");
  assert.ok(!result.beHost.includes("/"));
  assert.ok(!result.beHost.includes("?"));
  assert.ok(!result.beHost.includes("https"));
});
