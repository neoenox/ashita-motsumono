import { afterEach, describe, expect, it, vi } from 'vitest';

import worker from '../src/validated';

const signingSecret = '0123456789abcdef0123456789abcdef';

function rateLimiter() {
  return {
    async limit() {
      return { success: true };
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
    receiptHash: 'a'.repeat(64),
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
      today: '2026-08-23',
      timezone: 'Asia/Tokyo',
    }),
  });
}

function quotaStore(initial = '0') {
  return {
    get: vi.fn().mockResolvedValue(initial),
    put: vi.fn().mockResolvedValue(undefined),
  };
}

function runtimeEnv(quota: ReturnType<typeof quotaStore>) {
  return {
    REMOVE_ADS_PRODUCT_ID: 'remove_ads',
    AI_ACCESS_PRODUCT_ID: 'ai_analysis',
    MAX_IMAGE_BYTES: '5242880',
    GEMINI_API_KEY: 'gemini-test-key',
    ENTITLEMENT_SIGNING_SECRET: signingSecret,
    GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL: '',
    GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY: '',
    ANDROID_PACKAGE_NAME: 'com.ashita_motsumono',
    IOS_BUNDLE_ID: 'com.ashita_motsumono',
    AI_RATE_LIMITER: rateLimiter(),
    ENTITLEMENT_RATE_LIMITER: rateLimiter(),
    AI_DAILY_LIMIT: '5',
    AI_DAILY_QUOTA: quota,
  };
}

afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe('AI daily quota accounting', () => {
  it('does not consume quota when Gemini transport fails', async () => {
    const quota = quotaStore();
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('upstream timeout')));

    const response = await worker.fetch(
      analyzeRequest(await entitlementToken()),
      runtimeEnv(quota),
    );

    expect(response.status).toBe(502);
    expect(quota.get).toHaveBeenCalledOnce();
    expect(quota.put).not.toHaveBeenCalled();
  });

  it('does not consume quota when Gemini returns an error', async () => {
    const quota = quotaStore();
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        new Response(JSON.stringify({ error: 'upstream' }), { status: 500 }),
      ),
    );

    const response = await worker.fetch(
      analyzeRequest(await entitlementToken()),
      runtimeEnv(quota),
    );

    expect(response.status).toBe(502);
    expect(quota.put).not.toHaveBeenCalled();
  });

  it('commits quota after a successful Gemini response', async () => {
    const quota = quotaStore('2');
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        new Response(JSON.stringify({ drafts: [] }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        }),
      ),
    );

    const response = await worker.fetch(
      analyzeRequest(await entitlementToken()),
      runtimeEnv(quota),
    );

    expect(response.status).toBe(200);
    expect(quota.put).toHaveBeenCalledOnce();
    expect(quota.put).toHaveBeenCalledWith(
      expect.stringMatching(/^quota:a{64}:\d{4}-\d{2}-\d{2}$/u),
      '3',
      { expirationTtl: 172800 },
    );
  });
});
