import type {
  DurableObjectNamespace,
  QuotaReservation,
} from './quota';

const MODEL = 'gemini-2.5-flash';
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`;
const GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const MAX_REQUEST_BYTES = 8 * 1024 * 1024;
const DEFAULT_MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const DEFAULT_AI_DAILY_LIMIT = 200;
const QUOTA_TTL_SECONDS = 172800;
const TOKEN_TTL_SECONDS = 15 * 60;
const ALLOWED_MIME_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp']);

interface RateLimiter {
  limit(options: { key: string }): Promise<{ success: boolean }>;
}

interface DailyQuotaStore {
  get(key: string): Promise<string | null>;
  put(key: string, value: string, options: { expirationTtl?: number }): Promise<void>;
}

interface DailyQuota {
  reserve(dayKey: string, limit: number): Promise<boolean>;
  release(dayKey: string): Promise<void>;
}

interface Env {
  GEMINI_API_KEY: string;
  ENTITLEMENT_SIGNING_SECRET: string;
  GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL: string;
  GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY: string;
  ANDROID_PACKAGE_NAME: string;
  IOS_BUNDLE_ID: string;
  REMOVE_ADS_PRODUCT_ID: string;
  AI_ACCESS_PRODUCT_ID: string;
  MAX_IMAGE_BYTES?: string;
  AI_DAILY_LIMIT?: string;
  AI_QUOTA_COUNTER?: DurableObjectNamespace;
  AI_DAILY_QUOTA?: DailyQuotaStore;
  AI_RATE_LIMITER: RateLimiter;
  ENTITLEMENT_RATE_LIMITER: RateLimiter;
}

interface VerifyRequest {
  platform: 'android' | 'ios';
  productId: string;
  verificationData: string;
}

interface AnalysisRequest {
  imageBase64: string;
  mimeType: string;
  today?: string;
  timezone?: string;
}

interface EntitlementPayload {
  productId: string;
  platform: string;
  receiptHash: string;
  iat: number;
  exp: number;
}

interface CachedGoogleAccessToken {
  token: string;
  expiresAt: number;
  subject: string;
}

const encoder = new TextEncoder();
let cachedGoogleAccessToken: CachedGoogleAccessToken | null = null;
let pendingGoogleAccessToken: {
  subject: string;
  promise: Promise<string>;
} | null = null;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (request.method === 'GET' && url.pathname === '/health') {
      return json({ ok: true, model: MODEL });
    }
    if (request.method !== 'POST') {
      return json({ error: 'Method not allowed' }, 405);
    }
    if (url.pathname === '/entitlements/verify') {
      return verifyEntitlement(request, env);
    }
    if (url.pathname === '/analyze') {
      return analyze(request, env);
    }
    return json({ error: 'Not found' }, 404);
  },
};

async function verifyEntitlement(request: Request, env: Env): Promise<Response> {
  const ip = request.headers.get('CF-Connecting-IP') ?? 'unknown';
  const rate = await env.ENTITLEMENT_RATE_LIMITER.limit({ key: `verify:${ip}` });
  if (!rate.success) return json({ error: 'Too many verification attempts' }, 429);

  const body = await readJson<VerifyRequest>(request, 256 * 1024);
  if (body instanceof Response) return body;
  const allowedProducts = new Set([
    env.REMOVE_ADS_PRODUCT_ID,
    env.AI_ACCESS_PRODUCT_ID,
  ]);
  if (!allowedProducts.has(body.productId)) {
    return json({ error: 'Unknown product' }, 400);
  }
  if (!body.verificationData || body.verificationData.length > 200_000) {
    return json({ error: 'Invalid verification data' }, 400);
  }

  let verified = false;
  try {
    if (body.platform === 'android') {
      verified = await verifyGooglePlay(
        body.productId,
        body.verificationData,
        env,
      );
    } else if (body.platform === 'ios') {
      if (!env.IOS_BUNDLE_ID) {
        return json({ error: 'Store verification is not configured' }, 500);
      }
      verified = await verifyAppStore(
        body.productId,
        body.verificationData,
        env,
      );
    }
  } catch {
    return json({ error: 'Store verification is temporarily unavailable' }, 503);
  }
  if (!verified) return json({ error: 'Purchase could not be verified' }, 403);
  if (!env.ENTITLEMENT_SIGNING_SECRET || env.ENTITLEMENT_SIGNING_SECRET.length < 32) {
    return json({ error: 'Entitlement signing is not configured' }, 503);
  }

  const now = Math.floor(Date.now() / 1000);
  const payload: EntitlementPayload = {
    productId: body.productId,
    platform: body.platform,
    receiptHash: await sha256(body.verificationData),
    iat: now,
    exp: now + TOKEN_TTL_SECONDS,
  };
  const accessToken = await signEntitlement(
    payload,
    env.ENTITLEMENT_SIGNING_SECRET,
  );
  return json({
    verified: true,
    accessToken:
      body.productId === env.AI_ACCESS_PRODUCT_ID ? accessToken : undefined,
    expiresAt: new Date(payload.exp * 1000).toISOString(),
  });
}

async function analyze(request: Request, env: Env): Promise<Response> {
  const authorization = request.headers.get('Authorization') ?? '';
  if (!authorization.startsWith('Bearer ')) {
    return json({ error: 'Unauthorized' }, 401);
  }
  const entitlement = await verifyEntitlementToken(
    authorization.slice('Bearer '.length),
    env.ENTITLEMENT_SIGNING_SECRET,
  );
  if (!entitlement || entitlement.productId !== env.AI_ACCESS_PRODUCT_ID) {
    return json({ error: 'Unauthorized' }, 401);
  }

  const rate = await env.AI_RATE_LIMITER.limit({
    key: `ai:${entitlement.receiptHash}`,
  });
  if (!rate.success) return json({ error: 'Rate limit exceeded' }, 429);
  if (!env.GEMINI_API_KEY) return json({ error: 'AI service is not configured' }, 503);

  const body = await readJson<AnalysisRequest>(request, MAX_REQUEST_BYTES);
  if (body instanceof Response) return body;
  if (!body.imageBase64 || !ALLOWED_MIME_TYPES.has(body.mimeType)) {
    return json({ error: 'Invalid image request' }, 400);
  }
  if (!/^[A-Za-z0-9+/]*={0,2}$/.test(body.imageBase64)) {
    return json({ error: 'Invalid image encoding' }, 400);
  }
  const decodedBytes = Math.floor(body.imageBase64.length * 3 / 4);
  const maxImageBytes = Number(env.MAX_IMAGE_BYTES ?? DEFAULT_MAX_IMAGE_BYTES);
  if (!Number.isFinite(maxImageBytes) || decodedBytes <= 0 || decodedBytes > maxImageBytes) {
    return json({ error: 'Image too large' }, 413);
  }

  const today = /^\d{4}-\d{2}-\d{2}$/.test(body.today ?? '')
    ? body.today!
    : new Date().toISOString().slice(0, 10);
  const timezone = (body.timezone ?? 'Asia/Tokyo').slice(0, 64);
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: timezone });
  } catch {
    return json({ error: 'Invalid timezone' }, 400);
  }
  const prompt = `あなたは学校・園からのお知らせを解析するアシスタントです。
与えられた画像からTodo候補を抽出してください。
今日の日付は ${today}、タイムゾーンは ${timezone} です。
各候補は title、category、dueDate、amount、items、note を持ちます。
category は payment、submit、event、item、other のいずれかです。
相対日付は基準日から解決し、不明な日付は null にしてください。`;

  const geminiPayload = {
    contents: [{
      parts: [
        { text: prompt },
        {
          inline_data: {
            mime_type: body.mimeType,
            data: body.imageBase64,
          },
        },
      ],
    }],
    generationConfig: {
      response_mime_type: 'application/json',
      response_schema: {
        type: 'object',
        properties: {
          drafts: {
            type: 'array',
            maxItems: 20,
            items: {
              type: 'object',
              properties: {
                title: { type: 'string' },
                category: { type: 'string' },
                dueDate: { type: 'string', nullable: true },
                amount: { type: 'integer', nullable: true },
                items: { type: 'array', items: { type: 'string' } },
                note: { type: 'string', nullable: true },
              },
              required: ['title', 'category', 'items'],
            },
          },
        },
        required: ['drafts'],
      },
    },
  };

  // The daily quota is reserved atomically before the upstream call and
  // released again when the call fails, so Gemini outages never burn the
  // buyer's allowance. With the Durable Object binding the reserve is a single
  // serialized check-and-increment, so concurrent requests can never exceed
  // AI_DAILY_LIMIT (the KV fallback is only for local dev/tests and stays
  // eventually consistent).
  const quotaDate = new Date().toISOString().slice(0, 10);
  const dailyQuota = resolveDailyQuota(env, entitlement.receiptHash);

  if (dailyQuota) {
    let reserved: boolean;
    try {
      reserved = await dailyQuota.reserve(quotaDate, dailyQuotaLimit(env.AI_DAILY_LIMIT));
    } catch {
      return json({ error: 'Daily rate limit is temporarily unavailable' }, 503);
    }
    if (!reserved) {
      return json({ error: 'Daily rate limit exceeded' }, 429);
    }
  }

  try {
    const response = await fetch(GEMINI_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': env.GEMINI_API_KEY,
      },
      body: JSON.stringify(geminiPayload),
      signal: AbortSignal.timeout(55000),
    });
    if (!response.ok) {
      await dailyQuota?.release(quotaDate);
      if (response.status === 429) {
        return json({ error: 'Rate limit exceeded' }, 429);
      }
      return json({ error: 'Failed to call AI service' }, 502);
    }
    const data = await response.json();
    return json(data, response.status);
  } catch {
    await dailyQuota?.release(quotaDate);
    return json({ error: 'Failed to call AI service' }, 502);
  }
}

function resolveDailyQuota(env: Env, receiptHash: string): DailyQuota | null {
  if (env.AI_QUOTA_COUNTER) {
    return durableDailyQuota(env.AI_QUOTA_COUNTER, receiptHash);
  }
  if (env.AI_DAILY_QUOTA) {
    return kvDailyQuota(env.AI_DAILY_QUOTA, receiptHash);
  }
  return null;
}

function durableDailyQuota(
  namespace: DurableObjectNamespace,
  receiptHash: string,
): DailyQuota {
  const stub = namespace.get(namespace.idFromName(`ai-quota:${receiptHash}`));
  const call = async (
    action: 'reserve' | 'release',
    dayKey: string,
    limit?: number,
  ): Promise<QuotaReservation> => {
    const response = await stub.fetch(
      new Request('https://quota-counter.internal/', {
        method: 'POST',
        body: JSON.stringify({ action, key: dayKey, limit }),
      }),
    );
    if (!response.ok) throw new Error('Quota counter request failed');
    return await response.json() as QuotaReservation;
  };
  return {
    async reserve(dayKey: string, limit: number): Promise<boolean> {
      const reservation = await call('reserve', dayKey, limit);
      return reservation.allowed;
    },
    async release(dayKey: string): Promise<void> {
      try {
        await call('release', dayKey);
      } catch {
        // Best effort: a lost refund only over-counts by one and still never
        // exceeds the cap, so it must not mask the upstream error response.
      }
    },
  };
}

function kvDailyQuota(store: DailyQuotaStore, receiptHash: string): DailyQuota {
  const keyFor = (dayKey: string) => `quota:${receiptHash}:${dayKey}`;
  const current = async (key: string): Promise<number> =>
    Number(await store.get(key)) || 0;
  return {
    async reserve(dayKey: string, limit: number): Promise<boolean> {
      const key = keyFor(dayKey);
      const value = await current(key);
      if (value >= limit) return false;
      await store.put(key, String(value + 1), {
        expirationTtl: QUOTA_TTL_SECONDS,
      });
      return true;
    },
    async release(dayKey: string): Promise<void> {
      try {
        const key = keyFor(dayKey);
        const value = Math.max(0, await current(key) - 1);
        await store.put(key, String(value), { expirationTtl: QUOTA_TTL_SECONDS });
      } catch {
        // Best effort refund; see durableDailyQuota.
      }
    },
  };
}

async function verifyGooglePlay(
  productId: string,
  purchaseToken: string,
  env: Env,
): Promise<boolean> {
  if (
    !env.GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL ||
    !env.GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY ||
    !env.ANDROID_PACKAGE_NAME
  ) {
    return false;
  }
  const accessToken = await googleAccessToken(env);
  const base = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications';
  const resource = `${base}/${encodeURIComponent(env.ANDROID_PACKAGE_NAME)}` +
    `/purchases/products/${encodeURIComponent(productId)}` +
    `/tokens/${encodeURIComponent(purchaseToken)}`;
  const response = await fetch(resource, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!response.ok) return false;
  const purchase = await response.json() as {
    purchaseState?: number;
    acknowledgementState?: number;
  };
  if (purchase.purchaseState !== 0) return false;
  if (purchase.acknowledgementState === 0) {
    const acknowledge = await fetch(`${resource}:acknowledge`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: '{}',
    });
    if (!acknowledge.ok) return false;
  }
  return true;
}

async function googleAccessToken(env: Env): Promise<string> {
  const subject = env.GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL;
  const now = Math.floor(Date.now() / 1000);
  if (
    cachedGoogleAccessToken &&
    cachedGoogleAccessToken.subject === subject &&
    cachedGoogleAccessToken.expiresAt > now + 60
  ) {
    return cachedGoogleAccessToken.token;
  }

  const pending = pendingGoogleAccessToken;
  if (pending && pending.subject === subject) {
    return pending.promise;
  }

  const promise = fetchGoogleAccessToken(env, now);
  pendingGoogleAccessToken = { subject, promise };
  try {
    return await promise;
  } finally {
    if (pendingGoogleAccessToken?.promise === promise) {
      pendingGoogleAccessToken = null;
    }
  }
}

async function fetchGoogleAccessToken(env: Env, now: number): Promise<string> {
  const assertion = await signRs256Jwt(
    {
      iss: env.GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL,
      scope: 'https://www.googleapis.com/auth/androidpublisher',
      aud: GOOGLE_TOKEN_URL,
      iat: now,
      exp: now + 3600,
    },
    env.GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY,
  );
  const response = await fetch(GOOGLE_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!response.ok) throw new Error('Google OAuth failed');
  const payload = await response.json() as {
    access_token?: string;
    expires_in?: number;
  };
  if (!payload.access_token) throw new Error('Google OAuth token missing');
  const expiresIn = typeof payload.expires_in === 'number' && payload.expires_in > 0
    ? payload.expires_in
    : 3600;
  cachedGoogleAccessToken = {
    token: payload.access_token,
    expiresAt: now + expiresIn,
    subject: env.GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL,
  };
  return payload.access_token;
}

async function verifyAppStore(
  productId: string,
  receipt: string,
  env: Env,
): Promise<boolean> {
  const verify = async (host: string) => fetch(`${host}/verifyReceipt`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      'receipt-data': receipt,
      'exclude-old-transactions': true,
    }),
  });
  let response = await verify('https://buy.itunes.apple.com');
  let data = await response.json() as {
    status?: number;
    receipt?: {
      bundle_id?: string;
      in_app?: Array<{
        product_id?: string;
        cancellation_date?: string;
      }>;
    };
  };
  if (data.status === 21007) {
    response = await verify('https://sandbox.itunes.apple.com');
    data = await response.json() as typeof data;
  }
  if (!response.ok || data.status !== 0) return false;
  if (data.receipt?.bundle_id !== env.IOS_BUNDLE_ID) {
    return false;
  }
  return (data.receipt?.in_app ?? []).some(
    (purchase) =>
      purchase.product_id === productId && purchase.cancellation_date == null,
  );
}

async function signEntitlement(
  payload: EntitlementPayload,
  secret: string,
): Promise<string> {
  const header = base64UrlJson({ alg: 'HS256', typ: 'JWT' });
  const body = base64UrlJson(payload);
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'HMAC',
    key,
    encoder.encode(`${header}.${body}`),
  );
  return `${header}.${body}.${base64UrlBytes(new Uint8Array(signature))}`;
}

async function verifyEntitlementToken(
  token: string,
  secret: string,
): Promise<EntitlementPayload | null> {
  try {
    if (!secret) return null;
    const parts = token.split('.');
    if (parts.length !== 3) return null;

    const header = decodeBase64UrlJson(parts[0]);
    if (
      !isRecord(header) ||
      header.alg !== 'HS256' ||
      header.typ !== 'JWT'
    ) {
      return null;
    }

    const key = await crypto.subtle.importKey(
      'raw',
      encoder.encode(secret),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['verify'],
    );
    const valid = await crypto.subtle.verify(
      'HMAC',
      key,
      base64UrlDecode(parts[2]),
      encoder.encode(`${parts[0]}.${parts[1]}`),
    );
    if (!valid) return null;

    const payload = decodeBase64UrlJson(parts[1]);
    if (!isEntitlementPayload(payload)) return null;

    const now = Math.floor(Date.now() / 1000);
    if (
      payload.exp <= now ||
      payload.iat > now + 60 ||
      payload.exp <= payload.iat ||
      payload.exp - payload.iat > TOKEN_TTL_SECONDS
    ) {
      return null;
    }
    return payload;
  } catch {
    return null;
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isEntitlementPayload(value: unknown): value is EntitlementPayload {
  if (!isRecord(value)) return false;
  return (
    typeof value.productId === 'string' &&
    value.productId.length > 0 &&
    (value.platform === 'android' || value.platform === 'ios') &&
    typeof value.receiptHash === 'string' &&
    /^[a-f0-9]{64}$/.test(value.receiptHash) &&
    typeof value.iat === 'number' &&
    Number.isInteger(value.iat) &&
    typeof value.exp === 'number' &&
    Number.isInteger(value.exp)
  );
}

async function signRs256Jwt(
  payload: Record<string, unknown>,
  privateKeyPem: string,
): Promise<string> {
  const header = base64UrlJson({ alg: 'RS256', typ: 'JWT' });
  const body = base64UrlJson(payload);
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToBytes(privateKeyPem),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    encoder.encode(`${header}.${body}`),
  );
  return `${header}.${body}.${base64UrlBytes(new Uint8Array(signature))}`;
}

async function readJson<T>(
  request: Request,
  maxBytes: number,
): Promise<T | Response> {
  const contentType = request.headers.get('Content-Type') ?? '';
  if (!contentType.toLowerCase().startsWith('application/json')) {
    return json({ error: 'Content-Type must be application/json' }, 415);
  }
  const declared = Number(request.headers.get('Content-Length') ?? 0);
  if (declared > maxBytes) return json({ error: 'Request too large' }, 413);
  const text = await request.text();
  if (encoder.encode(text).byteLength > maxBytes) {
    return json({ error: 'Request too large' }, 413);
  }
  try {
    const value = JSON.parse(text);
    if (!value || typeof value !== 'object' || Array.isArray(value)) {
      throw new Error('Invalid JSON object');
    }
    return value as T;
  } catch {
    return json({ error: 'Invalid JSON' }, 400);
  }
}

function json(value: unknown, status = 200): Response {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
    },
  });
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', encoder.encode(value));
  return Array.from(
    new Uint8Array(digest),
    (byte) => byte.toString(16).padStart(2, '0'),
  ).join('');
}

function dailyQuotaLimit(value: string | undefined): number {
  const limit = Number.parseInt(value ?? '', 10);
  return Number.isInteger(limit) && limit >= 1
    ? limit
    : DEFAULT_AI_DAILY_LIMIT;
}

function base64UrlJson(value: unknown): string {
  return base64UrlBytes(encoder.encode(JSON.stringify(value)));
}

function base64UrlBytes(value: Uint8Array): string {
  let binary = '';
  for (const byte of value) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

function base64UrlDecode(value: string): Uint8Array {
  const normalized = value.replace(/-/g, '+').replace(/_/g, '/');
  const padded = normalized + '='.repeat((4 - normalized.length % 4) % 4);
  const binary = atob(padded);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

function decodeBase64UrlJson(value: string): unknown {
  return JSON.parse(new TextDecoder().decode(base64UrlDecode(value)));
}

function pemToBytes(pem: string): ArrayBuffer {
  const normalizedPem = pem.replace(/\\n/g, '\n');
  const base64 = normalizedPem.replace(
    /-----BEGIN [^-]+-----|-----END [^-]+-----|\s/g,
    '',
  );
  const binary = atob(base64);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0)).buffer;
}
