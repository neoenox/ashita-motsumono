import { describe, expect, it } from 'vitest';

import { readFileSync } from 'node:fs';

describe('AI daily quota concurrency contract', () => {
  it('does not claim KV accounting is an atomic strict quota', () => {
    const note = readFileSync(
      'workers/gemini-proxy/ATOMIC_QUOTA_TODO.md',
      'utf8',
    );

    expect(note).toContain('does not provide an atomic read-modify-write');
    expect(note).toContain('Durable Object');
  });
});
