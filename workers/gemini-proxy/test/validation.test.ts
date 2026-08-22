import { describe, expect, it } from 'vitest';

import { validateAnalysisBody, validateVerifyBody } from '../src/validated';

const verifyEnv = {
  REMOVE_ADS_PRODUCT_ID: 'remove_ads',
  AI_ACCESS_PRODUCT_ID: 'ai_analysis',
};

const analysisEnv = { MAX_IMAGE_BYTES: '5' };

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
