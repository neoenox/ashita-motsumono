import worker from './index';

export { QuotaCounter } from './quota';

const MAX_REQUEST_BYTES = 8 * 1024 * 1024;
const DEFAULT_MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const MAX_VERIFICATION_DATA_CHARS = 200_000;
const ALLOWED_MIME_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp']);

interface DailyQuotaStore {
  get(key: string): Promise<string | null>;
  put(
    key: string,
    value: string,
    options: { expirationTtl?: number },
  ): Promise<void>;
}

interface RuntimeEnv {
  REMOVE_ADS_PRODUCT_ID: string;
  AI_ACCESS_PRODUCT_ID: string;
  MAX_IMAGE_BYTES?: string;
  AI_DAILY_QUOTA?: DailyQuotaStore;
  [key: string]: unknown;
}

type JsonRecord = Record<string, unknown>;

class DeferredDailyQuotaStore implements DailyQuotaStore {
  private pendingWrites: Array<{
    key: string;
    value: string;
    options: { expirationTtl?: number };
  }> = [];

  constructor(private readonly delegate: DailyQuotaStore) {}

  get(key: string): Promise<string | null> {
    return this.delegate.get(key);
  }

  async put(
    key: string,
    value: string,
    options: { expirationTtl?: number },
  ): Promise<void> {
    this.pendingWrites.push({ key, value, options });
  }

  async commit(): Promise<void> {
    for (const write of this.pendingWrites) {
      await this.delegate.put(write.key, write.value, write.options);
    }
    this.pendingWrites = [];
  }
}

export function validateVerifyBody(
  value: unknown,
  env: Pick<RuntimeEnv, 'REMOVE_ADS_PRODUCT_ID' | 'AI_ACCESS_PRODUCT_ID'>,
): string | null {
  if (!isRecord(value)) return 'Invalid JSON object';
  if (value.platform !== 'android' && value.platform !== 'ios') {
    return 'Invalid platform';
  }
  if (typeof value.productId !== 'string' || value.productId.length === 0) {
    return 'Invalid product';
  }
  if (
    value.productId !== env.REMOVE_ADS_PRODUCT_ID &&
    value.productId !== env.AI_ACCESS_PRODUCT_ID
  ) {
    return 'Unknown product';
  }
  if (
    typeof value.verificationData !== 'string' ||
    value.verificationData.length === 0 ||
    value.verificationData.length > MAX_VERIFICATION_DATA_CHARS
  ) {
    return 'Invalid verification data';
  }
  return null;
}

export function validateAnalysisBody(
  value: unknown,
  env: Pick<RuntimeEnv, 'MAX_IMAGE_BYTES'>,
): { error: string; status: number } | null {
  if (!isRecord(value)) return { error: 'Invalid JSON object', status: 400 };
  if (typeof value.imageBase64 !== 'string' || value.imageBase64.length === 0) {
    return { error: 'Invalid image request', status: 400 };
  }
  if (typeof value.mimeType !== 'string' || !ALLOWED_MIME_TYPES.has(value.mimeType)) {
    return { error: 'Invalid image request', status: 400 };
  }
  if (!isStrictBase64(value.imageBase64)) {
    return { error: 'Invalid image encoding', status: 400 };
  }

  const maxImageBytes = Number(env.MAX_IMAGE_BYTES ?? DEFAULT_MAX_IMAGE_BYTES);
  if (!Number.isFinite(maxImageBytes) || maxImageBytes <= 0) {
    return { error: 'AI service image limit is misconfigured', status: 503 };
  }
  const decodedBytes = decodedBase64Bytes(value.imageBase64);
  if (decodedBytes <= 0 || decodedBytes > maxImageBytes) {
    return { error: 'Image too large', status: 413 };
  }

  if (value.today !== undefined) {
    if (typeof value.today !== 'string' || !isValidIsoDate(value.today)) {
      return { error: 'Invalid today date', status: 400 };
    }
  }
  if (value.timezone !== undefined) {
    if (
      typeof value.timezone !== 'string' ||
      value.timezone.length === 0 ||
      value.timezone.length > 64 ||
      !isValidTimeZone(value.timezone)
    ) {
      return { error: 'Invalid timezone', status: 400 };
    }
  }
  return null;
}

function isRecord(value: unknown): value is JsonRecord {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isStrictBase64(value: string): boolean {
  if (value.length === 0 || value.length % 4 !== 0) return false;
  return /^[A-Za-z0-9+/]+={0,2}$/.test(value);
}

function decodedBase64Bytes(value: string): number {
  const padding = value.endsWith('==') ? 2 : value.endsWith('=') ? 1 : 0;
  return (value.length / 4) * 3 - padding;
}

function isValidIsoDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value;
}

function isValidTimeZone(value: string): boolean {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: value }).format(new Date(0));
    return true;
  } catch {
    return false;
  }
}

function json(value: unknown, status: number): Response {
  return new Response(JSON.stringify(value), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
}

async function parseJsonClone(
  request: Request,
  maxBytes: number,
): Promise<unknown | Response> {
  const contentType = request.headers.get('Content-Type') ?? '';
  if (!contentType.toLowerCase().startsWith('application/json')) {
    return json({ error: 'Content-Type must be application/json' }, 415);
  }
  const declared = Number(request.headers.get('Content-Length') ?? 0);
  if (Number.isFinite(declared) && declared > maxBytes) {
    return json({ error: 'Request too large' }, 413);
  }
  const text = await request.clone().text();
  if (new TextEncoder().encode(text).byteLength > maxBytes) {
    return json({ error: 'Request too large' }, 413);
  }
  try {
    return JSON.parse(text) as unknown;
  } catch {
    return json({ error: 'Invalid JSON' }, 400);
  }
}

export default {
  async fetch(request: Request, env: RuntimeEnv): Promise<Response> {
    const path = new URL(request.url).pathname;
    if (request.method === 'POST') {
      if (path === '/entitlements/verify') {
        const body = await parseJsonClone(request, 256 * 1024);
        if (body instanceof Response) return body;
        const error = validateVerifyBody(body, env);
        if (error !== null) return json({ error }, 400);
      } else if (path === '/analyze' || path === '/') {
        const body = await parseJsonClone(request, MAX_REQUEST_BYTES);
        if (body instanceof Response) return body;
        const failure = validateAnalysisBody(body, env);
        if (failure !== null) return json({ error: failure.error }, failure.status);
      }
    }

    const delegate = worker as unknown as {
      fetch(request: Request, env: RuntimeEnv): Promise<Response>;
    };
    const quota = path === '/analyze' ? env.AI_DAILY_QUOTA : undefined;
    if (quota === undefined) {
      return delegate.fetch(request, env);
    }

    const deferredQuota = new DeferredDailyQuotaStore(quota);
    const response = await delegate.fetch(request, {
      ...env,
      AI_DAILY_QUOTA: deferredQuota,
    });
    if (!response.ok) {
      return response;
    }

    try {
      await deferredQuota.commit();
    } catch {
      return json({ error: 'AI daily quota is temporarily unavailable' }, 503);
    }
    return response;
  },
};
