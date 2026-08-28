import { afterEach, describe, expect, it, vi } from 'vitest';

import worker, {
  validateAnalysisBody,
  validateVerifyBody,
} from '../src/validated';

const verifyEnv = {
  REMOVE_ADS_PRODUCT_ID: 'remove_ads',
  AI_ACCESS_PRODUCT_ID: 'ai_analysis',
};

const analysisEnv = { MAX_IMAGE_BYTES: '5' };
const signingSecret = '0123456789abcdef0123456789abcdef';

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

async function entitlementToken(
  overrides: Partial<{
    productId: string;
    platform: string;
    receiptHash: string;
    iat: number;
    exp: number;
  }> = {},
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlJson({ alg: 'HS256', typ: 'JWT' });
  const payload = base64UrlJson({
    productId: 'ai_analysis',
    platform: 'ios',
    receiptHash: 'a'.repeat(64),
    iat: now,
    exp: now + 15 * 60,
    ...overrides,
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

function runtimeEnv(
  options: {
    aiRateAllowed?: boolean;
    verifyRateAllowed?: boolean;
    aiDailyQuota?: QuotaStore;
    aiDailyLimit?: number;
  } = {},
) {
  return {
    ...verifyEnv,
    MAX_IMAGE_BYTES: '5242880',
    GEMINI_API_KEY: 'gemini-test-key',
    ENTITLEMENT_SIGNING_SECRET: signingSecret,
    GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL: '',
    GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY: '',
    ANDROID_PACKAGE_NAME: 'com.ashita_motsumono',
    IOS_BUNDLE_ID: 'com.ashita_motsumono',
    AI_RATE_LIMITER: rateLimiter(options.aiRateAllowed ?? true),
    ENTITLEMENT_RATE_LIMITER: rateLimiter(options.verifyRateAllowed ?? true),
    ...(options.aiDailyQuota
      ? {
          AI_DAILY_QUOTA: options.aiDailyQuota,
          ...(options.aiDailyLimit !== undefined
            ? { AI_DAILY_LIMIT: String(options.aiDailyLimit) }
            : {}),
        }
      : {}),
  };
}

interface QuotaStore {
  readonly size: number;
  value(key: string): number | undefined;
  get(key: string): Promise<string | null>;
  put(key: string, value: string): Promise<void>;
}

function quotaStore(): QuotaStore {
  const entries = new Map<string, number>();
  return {
    get size() {
      return entries.size;
    },
    value: (key) => entries.get(key),
    async get(key) {
      return entries.has(key) ? String(entries.get(key)!) : null;
    },
    async put(key, value) {
      entries.set(key, Number(value));
    },
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
      today: '2026-08-22',
      timezone: 'Asia/Tokyo',
    }),
  });
}

afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe('purchase verification request validation', () => {
  it('accepts known products on supported platforms', () => {
    expect(
      validateVerifyBody(
        { platform: 'android', productId: 'remove_ads', verificationData: 'token' },
        verifyEnv,
      ),
    ).toBeNull();
    expect(
      validateVerifyBody(
        { platform: 'ios', productId: 'ai_analysis', verificationData: 'receipt' },
        verifyEnv,
      ),
    ).toBeNull();
  });

  it('fails closed on unknown platform and product', () => {
    expect(
      validateVerifyBody(
        { platform: 'web', productId: 'remove_ads', verificationData: 'token' },
        verifyEnv,
      ),
    ).toBe('Invalid platform');
    expect(
      validateVerifyBody(
        { platform: 'android', productId: 'other', verificationData: 'token' },
        verifyEnv,
      ),
    ).toBe('Unknown product');
  });

  it('rejects empty and oversized verification data', () => {
    expect(
      validateVerifyBody(
        { platform: 'android', productId: 'remove_ads', verificationData: '' },
        verifyEnv,
      ),
    ).toBe('Invalid verification data');
    expect(
      validateVerifyBody(
        {
          platform: 'android',
          productId: 'remove_ads',
          verificationData: 'x'.repeat(200_001),
        },
        verifyEnv,
      ),
    ).toBe('Invalid verification data');
  });
});

describe('analysis request validation', () => {
  it('accepts valid image, date and IANA timezone', () => {
    expect(
      validateAnalysisBody(
        {
          imageBase64: 'AQIDBA==',
          mimeType: 'image/png',
          today: '2026-08-22',
          timezone: 'Asia/Tokyo',
        },
        { MAX_IMAGE_BYTES: '4' },
      ),
    ).toBeNull();
  });

  it('rejects malformed base64 and unsupported MIME', () => {
    expect(
      validateAnalysisBody(
        { imageBase64: 'not base64', mimeType: 'image/png' },
        analysisEnv,
      ),
    ).toEqual({ error: 'Invalid image encoding', status: 400 });
    expect(
      validateAnalysisBody(
        { imageBase64: 'AQIDBA==', mimeType: 'image/svg+xml' },
        analysisEnv,
      ),
    ).toEqual({ error: 'Invalid image request', status: 400 });
  });

  it('enforces decoded byte boundary exactly', () => {
    expect(
      validateAnalysisBody(
        { imageBase64: 'AQIDBA==', mimeType: 'image/png' },
        { MAX_IMAGE_BYTES: '4' },
      ),
    ).toBeNull();
    expect(
      validateAnalysisBody(
        { imageBase64: 'AQIDBA==', mimeType: 'image/png' },
        { MAX_IMAGE_BYTES: '3' },
      ),
    ).toEqual({ error: 'Image too large', status: 413 });
  });

  it('rejects impossible calendar dates', () => {
    expect(
      validateAnalysisBody(
        {
          imageBase64: 'AQIDBA==',
          mimeType: 'image/png',
          today: '2026-02-30',
        },
        analysisEnv,
      ),
    ).toEqual({ error: 'Invalid today date', status: 400 });
  });

  it('rejects invalid timezone names and oversized timezone input', () => {
    expect(
      validateAnalysisBody(
        {
          imageBase64: 'AQIDBA==',
          mimeType: 'image/png',
          timezone: 'Not/A_Real_Zone',
        },
        analysisEnv,
      ),
    ).toEqual({ error: 'Invalid timezone', status: 400 });
    expect(
      validateAnalysisBody(
        {
          imageBase64: 'AQIDBA==',
          mimeType: 'image/png',
          timezone: 'A'.repeat(65),
        },
        analysisEnv,
      ),
    ).toEqual({ error: 'Invalid timezone', status: 400 });
  });

  it('fails closed when image size configuration is invalid', () => {
    expect(
      validateAnalysisBody(
        { imageBase64: 'AQIDBA==', mimeType: 'image/png' },
        { MAX_IMAGE_BYTES: 'NaN' },
      ),
    ).toEqual({ error: 'AI service image limit is misconfigured', status: 503 });
  });
});

describe('public Worker security boundary', () => {
  it('rejects tampered, expired, future and wrong-product entitlement tokens', async () => {
    const now = Math.floor(Date.now() / 1000);
    const cases = [
      `${await entitlementToken()}x`,
      await entitlementToken({ iat: now - 100, exp: now - 1 }),
      await entitlementToken({ iat: now + 61, exp: now + 120 }),
      await entitlementToken({ productId: 'remove_ads' }),
    ];

    for (const token of cases) {
      const response = await worker.fetch(analyzeRequest(token), runtimeEnv());
      expect(response.status).toBe(401);
      await expect(response.json()).resolves.toEqual({ error: 'Unauthorized' });
    }
  });

  it('rejects valid entitlement when AI rate limit is exhausted', async () => {
    const token = await entitlementToken();
    const response = await worker.fetch(
      analyzeRequest(token),
      runtimeEnv({ aiRateAllowed: false }),
    );

    expect(response.status).toBe(429);
    await expect(response.json()).resolves.toEqual({ error: 'Rate limit exceeded' });
  });

  it('authenticates before pulling an unauthenticated request body', async () => {
    let pullCount = 0;
    const body = new ReadableStream<Uint8Array>({
      pull(controller) {
        pullCount += 1;
        controller.enqueue(new Uint8Array(1024));
      },
    });
    await Promise.resolve();
    const pullsBeforeFetch = pullCount;
    const response = await worker.fetch(
      new Request('https://worker.example/analyze', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body,
        duplex: 'half',
      } as RequestInit),
      runtimeEnv(),
    );

    expect(response.status).toBe(401);
    expect(pullCount).toBe(pullsBeforeFetch);
  });

  it('stops reading an oversized authenticated stream at max plus one chunk', async () => {
    const token = await entitlementToken();
    const chunk = new Uint8Array(1024 * 1024);
    let pullCount = 0;
    const body = new ReadableStream<Uint8Array>({
      pull(controller) {
        pullCount += 1;
        controller.enqueue(chunk);
      },
    });
    await Promise.resolve();
    const pullsBeforeFetch = pullCount;
    const response = await worker.fetch(
      new Request('https://worker.example/analyze', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body,
        duplex: 'half',
      } as RequestInit),
      runtimeEnv(),
    );

    expect(response.status).toBe(413);
    expect(pullCount - pullsBeforeFetch).toBeLessThanOrEqual(9);
  });

  it('turns Gemini transport failure into a bounded 502 response', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('upstream timeout')));
    const token = await entitlementToken();
    const response = await worker.fetch(analyzeRequest(token), runtimeEnv());

    expect(response.status).toBe(502);
    await expect(response.json()).resolves.toEqual({ error: 'Failed to call AI service' });
  });

  it('does not consume the daily quota when the upstream call fails', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('upstream timeout')));
    const quota = quotaStore();
    const token = await entitlementToken();
    const response = await worker.fetch(
      analyzeRequest(token),
      runtimeEnv({ aiDailyQuota: quota }),
    );

    expect(response.status).toBe(502);
    expect(quota.size).toBe(0);
  });

  it('consumes the daily quota only after a successful upstream call', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(Response.json({ drafts: [] })),
    );
    const quota = quotaStore();
    const token = await entitlementToken();
    const key = `quota:${'a'.repeat(64)}:${new Date().toISOString().slice(0, 10)}`;
    const response = await worker.fetch(
      analyzeRequest(token),
      runtimeEnv({ aiDailyQuota: quota }),
    );

    expect(response.status).toBe(200);
    expect(quota.value(key)).toBe(1);
  });

  it('rejects with 429 without calling upstream once the daily limit is reached', async () => {
    const fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);
    const quota = quotaStore();
    const key = `quota:${'a'.repeat(64)}:${new Date().toISOString().slice(0, 10)}`;
    await quota.put(key, '2');
    const token = await entitlementToken();
    const response = await worker.fetch(
      analyzeRequest(token),
      runtimeEnv({ aiDailyQuota: quota, aiDailyLimit: 2 }),
    );

    expect(response.status).toBe(429);
    await expect(response.json()).resolves.toEqual({ error: 'Daily rate limit exceeded' });
    expect(fetchMock).not.toHaveBeenCalled();
    expect(quota.value(key)).toBe(2);
  });

  it('rate-limits entitlement verification before calling a store', async () => {
    const response = await worker.fetch(
      new Request('https://worker.example/entitlements/verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          platform: 'ios',
          productId: 'ai_analysis',
          verificationData: 'receipt',
        }),
      }),
      runtimeEnv({ verifyRateAllowed: false }),
    );

    expect(response.status).toBe(429);
    await expect(response.json()).resolves.toEqual({
      error: 'Too many verification attempts',
    });
  });

  it('treats App Store transport failure as retryable service failure', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('store timeout')));
    const response = await worker.fetch(
      new Request('https://worker.example/entitlements/verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          platform: 'ios',
          productId: 'ai_analysis',
          verificationData: 'receipt',
        }),
      }),
      runtimeEnv(),
    );

    expect(response.status).toBe(503);
    await expect(response.json()).resolves.toEqual({
      error: 'Store verification is temporarily unavailable',
    });
  });
});
