// Test cho src/lib/tracing.ts và src/lib/tracing-sampler.ts (D21, tracing `fe`). Cùng kiểu với
// health.test.mjs: .mjs thuần, node:test, import thẳng file .ts.
import { test } from "node:test";
import assert from "node:assert/strict";
import { ROOT_CONTEXT, SpanKind, TraceFlags, propagation, trace } from "@opentelemetry/api";
import { SamplingDecision } from "@opentelemetry/sdk-trace-node";
import { currentTraceparent } from "./tracing.ts";
import { createFeSampler, shouldTrace } from "./tracing-sampler.ts";

const TRACE_ID = "0af7651916cd43dd8448eb211c80319c";

function parent(sampled, isRemote) {
  return trace.setSpanContext(ROOT_CONTEXT, {
    traceId: TRACE_ID,
    spanId: "b7ad6b7169203331",
    traceFlags: sampled ? TraceFlags.SAMPLED : TraceFlags.NONE,
    isRemote,
  });
}

function decide(ctx, target) {
  const attributes = target === undefined ? {} : { "http.target": target };
  return createFeSampler().shouldSample(ctx, TRACE_ID, "GET", SpanKind.SERVER, attributes, [])
    .decision;
}

test("probe, poll va asset tinh khong trace", () => {
  for (const url of [
    "/api/version",
    "/api/health",
    "/api/health?x=1",
    "/_next/static/chunks/a.js",
    "/favicon.ico",
  ]) {
    assert.equal(shouldTrace(url), false, url);
  }
});

test("trang va route ghi van trace", () => {
  for (const url of ["/", "/tickets/1", "/api/tickets", "/api/tickets/1/status", "/stats?x=1"]) {
    assert.equal(shouldTrace(url), true, url);
  }
});

test("url rong van trace (khong nuot request la)", () => {
  assert.equal(shouldTrace(undefined), true);
});

test("sampler: span goc /api/version bi bo, /tickets duoc giu", () => {
  assert.equal(decide(ROOT_CONTEXT, "/api/version"), SamplingDecision.NOT_RECORD);
  assert.equal(decide(ROOT_CONTEXT, "/tickets"), SamplingDecision.RECORD_AND_SAMPLED);
});

test("sampler: traceparent cua trinh duyet (ke ca co -00) van loc theo path", () => {
  assert.equal(decide(parent(false, true), "/tickets"), SamplingDecision.RECORD_AND_SAMPLED);
  assert.equal(decide(parent(true, true), "/api/version"), SamplingDecision.NOT_RECORD);
});

test("sampler: span con theo cha local (cha probe bi bo -> con bo)", () => {
  assert.equal(decide(parent(false, false), undefined), SamplingDecision.NOT_RECORD);
  assert.equal(decide(parent(true, false), undefined), SamplingDecision.RECORD_AND_SAMPLED);
});

test("telemetry tat (propagator no-op) -> undefined, noi goi giu traceparent cua trinh duyet", () => {
  assert.equal(currentTraceparent(), undefined);
});

test("telemetry bat -> lay traceparent tu propagator toan cuc", () => {
  const value = `00-${TRACE_ID}-b7ad6b7169203331-01`;
  propagation.setGlobalPropagator({
    inject: (_ctx, carrier, setter) => setter.set(carrier, "traceparent", value),
    extract: (ctx) => ctx,
    fields: () => ["traceparent"],
  });
  try {
    assert.equal(currentTraceparent(), value);
  } finally {
    propagation.disable();
  }
});
