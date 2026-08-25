export interface DurableObjectStorage {
  get<T = unknown>(key: string): Promise<T | undefined>;
  put<T>(key: string, value: T): Promise<void>;
}

export interface DurableObjectState {
  storage: DurableObjectStorage;
}

export interface DurableObjectId {
  toString(): string;
}

export interface DurableObjectStub {
  fetch(request: Request): Promise<Response>;
}

export interface DurableObjectNamespace {
  idFromName(name: string): DurableObjectId;
  get(id: DurableObjectId): DurableObjectStub;
}

export interface QuotaReservation {
  allowed: boolean;
  count: number;
}

interface QuotaAction {
  action?: unknown;
  key?: unknown;
  limit?: unknown;
}

const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

function jsonResponse(value: unknown, status = 200): Response {
  return new Response(JSON.stringify(value), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
}

function isValidDayKey(value: unknown): value is string {
  return typeof value === 'string' && DATE_PATTERN.test(value);
}

function isValidLimit(value: unknown): value is number {
  return typeof value === 'number' && Number.isInteger(value) && value >= 1;
}

export class QuotaCounter {
  private tail: Promise<unknown> = Promise.resolve();

  constructor(private readonly state: DurableObjectState) {}

  async fetch(request: Request): Promise<Response> {
    if (request.method !== 'POST') {
      return jsonResponse({ error: 'Method not allowed' }, 405);
    }
    let payload: QuotaAction;
    try {
      payload = await request.json() as QuotaAction;
    } catch {
      return jsonResponse({ error: 'Invalid JSON' }, 400);
    }
    if (!isValidDayKey(payload.key)) {
      return jsonResponse({ error: 'Invalid quota key' }, 400);
    }
    if (payload.action === 'reserve') {
      if (!isValidLimit(payload.limit)) {
        return jsonResponse({ error: 'Invalid quota limit' }, 400);
      }
      const reservation = await this.reserve(payload.key, payload.limit);
      return jsonResponse(reservation);
    }
    if (payload.action === 'release') {
      const result = await this.release(payload.key);
      return jsonResponse(result);
    }
    return jsonResponse({ error: 'Unknown quota action' }, 400);
  }

  reserve(dayKey: string, limit: number): Promise<QuotaReservation> {
    return this.serialize(async () => {
      const stored = await this.state.storage.get<number>(dayKey);
      const current = typeof stored === 'number' && Number.isInteger(stored) && stored >= 0
        ? stored
        : 0;
      if (current >= limit) {
        return { allowed: false, count: current };
      }
      const next = current + 1;
      await this.state.storage.put(dayKey, next);
      return { allowed: true, count: next };
    });
  }

  release(dayKey: string): Promise<{ count: number }> {
    return this.serialize(async () => {
      const stored = await this.state.storage.get<number>(dayKey);
      const current = typeof stored === 'number' && Number.isInteger(stored) && stored >= 0
        ? stored
        : 0;
      if (current === 0) return { count: 0 };
      const next = current - 1;
      await this.state.storage.put(dayKey, next);
      return { count: next };
    });
  }

  private serialize<T>(task: () => Promise<T>): Promise<T> {
    const result = this.tail.then(task, task);
    this.tail = result.then(
      () => undefined,
      () => undefined,
    );
    return result;
  }
}
