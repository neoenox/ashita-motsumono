import { afterEach, describe, expect, it, vi } from 'vitest';

import worker from '../src/validated';
import {
  QuotaCounter,
  type DurableObjectNamespace,
  type DurableObjectStub,
} from '../src/quota';

const signingSecret = '0123456789abcdef0123456789abcdef';
const receiptHash = 'a'.repeat(64);
const DAY_1 = '2026-08-23';
const DAY_2 = '2026-08-24';

function rateLimiter(success = true) {
  return {
    async limit() {
      return { success };
    },
  };
}

function base64UrlBytes(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replace(/=+$/u, '');
}

function base64UrlJson(value: unknown): string {
  return base64UrlBytes(new TextEncoder().encode(JSON.stringify(value)));
}

async function entitlementToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlJson({ alg: 'HS256', typ: 'JWT' });
  const payload = base64UrlJson({
    productId: 'ai_analysis',
    platform: 'ios',
    receiptHash,
    iat: now,
    exp: now + 15 * 60,
  });
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(signingSecret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'HMAC',
    key,
    new TextEncoder().encode(`${header}.${payload}`),
  );
  return `${header}.${payload}.${base64UrlBytes(new Uint8Array(signature))}`;
}

interface FakeCounterObject {
  counter: QuotaCounter;
  map: Map<string, number>;
}

function fakeState() {
  const map = new Map<string, number>();
  const state = {
    storage: {
      async get<T = unknown>(key: string): Promise<T | undefined> {
        return map.get(key) as T | undefined;
      },
      async put<T>(key: string, value: T): Promise<void> {
        map.set(key, Number(value));
      },
    },
  };
  return { state, map };
}

interface FakeNamespace extends DurableObjectNamespace {
  counts(dayKey?: string): number | Map<string, number>;
}

function quotaNamespace(): FakeNamespace {
  const objects = new Map<string, FakeCounterObject>();
  const namespace: DurableObjectNamespace = {
    idFromName(name: string) {
      return { toString: () => name };
    },
    get(id) {
      const name = id.toString();
      let object = objects.get(name);
      if (!object) {
        const { state, map } = fakeState();
        object = { counter: new QuotaCounter(state), map };
        objects.set(name, object);
      }
      return {
        fetch: (request: Request) => object!.counter.fetch(request),
      } satisfies DurableObjectStub;
    },
  };
  return Object.assign(namespace, {
    counts(dayKey?: string): number | Map<string, number> {
      const map = objects.get(`ai-quota:${receiptHash}`)?.map ?? new Map();
      return dayKey === undefined ? map : map.get(dayKey) ?? 0;
    },
  });
}

function brokenNamespace(): DurableObjectNamespace {
  return {
    idFromName(name: string) {
      return { toString: () => name };
    },
    get() {
      return {
        async fetch() {
          throw new Error('durable object is down');
        },
      };
    },
  };
}

function kvStore() {
  const entries = new Map<string, number>();
  return {
    get size() {
      return entries.size;
    },
    value(key: string): number | undefined {
      return entries.get(key);
    },
    async get(key: string): Promise<string | null> {
      return entries.has(key) ? String(entries.get(key)!) : null;
    },
    async put(
      key: string,
      value: string,
      _options: { expirationTtl?: number } = {},
    ): Promise<void> {
      entries.set(key, Number(value));
    },
  };
}

type QuotaBinding =
  | { kind: 'do'; namespace?: DurableObjectNamespace }
  | { kind: 'kv'; store?: ReturnType<typeof kvStore> };

function runtimeEnv(options: { quota?: QuotaBinding; aiDailyLimit?: number } = {}) {
  const quota = options.quota ?? { kind: 'do' as const };
  return {
    MAX_IMAGE_BYTES: '5242880',
    GEMINI_API_KEY: 'gemini-test-key',
    ENTITLEMENT_SIGNING_SECRET: signingSecret,
    GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL: '',
    GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY: '',
    ANDROID_PACKAGE_NAME: 'com.ashita_motsumono',
    IOS_BUNDLE_ID: 'com.ashita_motsumono',
    REMOVE_ADS_PRODUCT_ID: 'remove_ads',
    AI_ACCESS_PRODUCT_ID: 'ai_analysis',
    AI_RATE_LIMITER: rateLimiter(true),
    ENTITLEMENT_RATE_LIMITER: rateLimiter(true),
    ...(quota.kind === 'do'
      ? { AI_QUOTA_COUNTER: quota.namespace ?? quotaNamespace() }
      : quota.store
        ? { AI_DAILY_QUOTA: quota.store }
        : {}),
    ...(options.aiDailyLimit !== undefined
      ? { AI_DAILY_LIMIT: String(options.aiDailyLimit) }
      : {}),
  };
}

function analyzeRequest(token: string): Request {
  return new Request('https://worker.example/analyze', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({
      imageBase64: 'AQIDBA==',
      mimeType: 'image/png',
      today: DAY_1,
      timezone: 'Asia/Tokyo',
    }),
  });
}

async function successfulAnalyze(env: Record<string, unknown>): Promise<Response> {
  const token = await entitlementToken();
  return worker.fetch(analyzeRequest(token), env as never);
}

function reserveRequest(body: unknown): Request {
  return new Request('https://counter.internal/', {
    method: 'POST',
    body: JSON.stringify(body),
  });
}

afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe('QuotaCounter durable object', () => {
  it('serializes concurrent reserves so the count never exceeds the limit', async () => {
    const { state } = fakeState();
    const counter = new QuotaCounter(state);

    const results = await Promise.all(
      Array.from({ length: 20 }, () =>
        counter.fetch(reserveRequest({ action: 'reserve', key: DAY_1, limit: 5 })),
      ),
    );
    const payloads = await Promise.all(results.map((response) => response.json()));

    expect(payloads.filter((p) => p.allowed)).toHaveLength(5);
    expect(payloads.filter((p) => !p.allowed)).toHaveLength(15);
    expect(state.storage).toBeDefined();
  });

  it('reports the stored count when denying and releases floor at zero', async () => {
    const { state } = fakeState();
    const counter = new QuotaCounter(state);

    for (let i = 0; i < 3; i++) {
      await counter.fetch(reserveRequest({ action: 'reserve', key: DAY_1, limit: 2 }));
    }
    await expect(
      counter.fetch(reserveRequest({ action: 'reserve', key: DAY_1, limit: 2 })).then((r) => r.json()),
    ).resolves.toEqual({ allowed: false, count: 2 });

    for (let i = 0; i < 5; i++) {
      await counter.release(DAY_1);
    }
    expect(await state.storage.get(DAY_1)).toBe(0);

    await expect(counter.reserve(DAY_1, 2)).resolves.toEqual({ allowed: true, count: 1 });
  });

  it('starts a fresh count per UTC day key', async () => {
    const { state } = fakeState();
    const counter = new QuotaCounter(state);

    await counter.reserve(DAY_1, 2);
    await counter.reserve(DAY_1, 2);
    await expect(counter.reserve(DAY_1, 2)).resolves.toEqual({
      allowed: false,
      count: 2,
    });
    await expect(counter.reserve(DAY_2, 2)).resolves.toEqual({
      allowed: true,
      count: 1,
    });
  });

  it('rejects malformed requests', async () => {
    const counter = new QuotaCounter(fakeState().state);
    const get = await counter.fetch(
      new Request('https://counter.internal/', { method: 'GET' }),
    );
    expect(get.status).toBe(405);

    const badJson = await counter.fetch(
      new Request('https://counter.internal/', { method: 'POST', body: 'not json' }),
    );
    expect(badJson.status).toBe(400);

    const badKey = await counter.fetch(
      reserveRequest({ action: 'reserve', key: 'not-a-date', limit: 1 }),
    );
    expect(badKey.status).toBe(400);

    const badLimit = await counter.fetch(
      reserveRequest({ action: 'reserve', key: DAY_1, limit: 0 }),
    );
    expect(badLimit.status).toBe(400);

    const unknownAction = await counter.fetch(
      reserveRequest({ action: 'noop', key: DAY_1 }),
    );
    expect(unknownAction.status).toBe(400);
  });
});

describe('/analyze daily quota via Durable Object', () => {
  it('consumes one unit per successful Gemini call', async () => {
    vi.stubGlobal('fetch', vi.fn(() => Response.json({ drafts: [] })));
    const namespace = quotaNamespace();
    const response = await successfulAnalyze(runtimeEnv({ quota: { kind: 'do', namespace } }));

    expect(response.status).toBe(200);
    const today = new Date().toISOString().slice(0, 10);
    expect(namespace.counts(today)).toBe(1);
  });

  it('refunds the reservation when the upstream call fails', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('upstream timeout')));
    const namespace = quotaNamespace();
    const response = await successfulAnalyze(runtimeEnv({ quota: { kind: 'do', namespace } }));

    expect(response.status).toBe(502);
    const today = new Date().toISOString().slice(0, 10);
    expect(namespace.counts(today)).toBe(0);
  });

  it('refunds the reservation when Gemini answers 429', async () => {
    vi.stubGlobal('fetch', vi.fn(() => new Response('{}', { status: 429 })));
    const namespace = quotaNamespace();
    const response = await successfulAnalyze(runtimeEnv({ quota: { kind: 'do', namespace } }));

    expect(response.status).toBe(429);
    const today = new Date().toISOString().slice(0, 10);
    expect(namespace.counts(today)).toBe(0);
  });

  it('never exceeds the daily cap under concurrent requests', async () => {
    vi.stubGlobal('fetch', vi.fn(() => Response.json({ drafts: [] })));
    const namespace = quotaNamespace();
    const env = runtimeEnv({ quota: { kind: 'do', namespace }, aiDailyLimit: 3 });
    const token = await entitlementToken();

    const responses = await Promise.all(
      Array.from({ length: 10 }, () => worker.fetch(analyzeRequest(token), env as never)),
    );
    const statuses = await Promise.all(responses.map((r) => r.status));

    expect(statuses.filter((status) => status === 200)).toHaveLength(3);
    expect(statuses.filter((status) => status === 429)).toHaveLength(7);
    const today = new Date().toISOString().slice(0, 10);
    expect(namespace.counts(today)).toBe(3);
  });

  it('resets the count on UTC day rollover', async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: new Date(`${DAY_1}T12:00:00Z`) });
    vi.stubGlobal('fetch', vi.fn(() => Response.json({ drafts: [] })));
    const namespace = quotaNamespace();
    const env = runtimeEnv({ quota: { kind: 'do', namespace }, aiDailyLimit: 2 });

    expect((await successfulAnalyze(env)).status).toBe(200);
    expect((await successfulAnalyze(env)).status).toBe(200);
    const exhausted = await successfulAnalyze(env);
    expect(exhausted.status).toBe(429);
    await expect(exhausted.json()).resolves.toEqual({ error: 'Daily rate limit exceeded' });

    vi.setSystemTime(new Date(`${DAY_2}T00:00:01Z`));
    const nextDay = await successfulAnalyze(env);
    expect(nextDay.status).toBe(200);
    expect(namespace.counts(DAY_1)).toBe(2);
    expect(namespace.counts(DAY_2)).toBe(1);
  });

  it('fails closed with 503 when the durable object is unreachable', async () => {
    const fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);
    const response = await successfulAnalyze(
      runtimeEnv({ quota: { kind: 'do', namespace: brokenNamespace() } }),
    );

    expect(response.status).toBe(503);
    await expect(response.json()).resolves.toEqual({
      error: 'Daily rate limit is temporarily unavailable',
    });
    expect(fetchMock).not.toHaveBeenCalled();
  });
});

describe('/analyze daily quota via KV fallback', () => {
  it('consumes one unit per successful Gemini call', async () => {
    vi.stubGlobal('fetch', vi.fn(() => Response.json({ drafts: [] })));
    const store = kvStore();
    const response = await successfulAnalyze(runtimeEnv({ quota: { kind: 'kv', store } }));

    expect(response.status).toBe(200);
    const today = new Date().toISOString().slice(0, 10);
    expect(store.value(`quota:${receiptHash}:${today}`)).toBe(1);
  });

  it('does not consume quota when the upstream call fails', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('upstream timeout')));
    const store = kvStore();
    const response = await successfulAnalyze(runtimeEnv({ quota: { kind: 'kv', store } }));

    expect(response.status).toBe(502);
    const today = new Date().toISOString().slice(0, 10);
    // The failed upstream call must refund the reservation. A zero value may
    // be represented by an absent KV key in a fake/local implementation.
    expect(store.value(`quota:${receiptHash}:${today}`) ?? 0).toBe(0);
  });

  it('rejects with 429 without calling upstream once the limit is reached', async () => {
    const fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);
    const store = kvStore();
    const today = new Date().toISOString().slice(0, 10);
    store.value(`quota:${receiptHash}:${today}`);
    await store.put(`quota:${receiptHash}:${today}`, '2');
    const response = await successfulAnalyze(
      runtimeEnv({ quota: { kind: 'kv', store }, aiDailyLimit: 2 }),
    );

    expect(response.status).toBe(429);
    await expect(response.json()).resolves.toEqual({ error: 'Daily rate limit exceeded' });
    expect(fetchMock).not.toHaveBeenCalled();
    expect(store.value(`quota:${receiptHash}:${today}`)).toBe(2);
  });

  it('refunds a reserved unit when the upstream call fails mid-day', async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce(Response.json({ drafts: [] }))
      .mockRejectedValueOnce(new Error('upstream timeout'));
    vi.stubGlobal('fetch', fetchMock);
    const store = kvStore();
    const today = new Date().toISOString().slice(0, 10);

    expect((await successfulAnalyze(runtimeEnv({ quota: { kind: 'kv', store } }))).status).toBe(200);
    expect((await successfulAnalyze(runtimeEnv({ quota: { kind: 'kv', store } }))).status).toBe(502);
    expect(store.value(`quota:${receiptHash}:${today}`)).toBe(1);
  });
});
