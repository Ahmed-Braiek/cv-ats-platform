import test from 'node:test';
import assert from 'node:assert/strict';
import {activeGeminiKeys, keyAtSlot} from './gemini_key_rotation.ts';

test('three configured Gemini keys have stable order', () => {
  const env = {
    GEMINI_API_KEY_PRIMARY: 'key-one',
    GEMINI_API_KEY_SECONDARY: 'key-two',
    GEMINI_API_KEY_TERTIARY: 'key-three',
  };
  const keys = activeGeminiKeys((name) => env[name]);
  assert.deepEqual(keys, ['key-one', 'key-two', 'key-three']);
  assert.deepEqual([1, 2, 3, 1].map((slot) => keyAtSlot(keys, slot)),
    ['key-one', 'key-two', 'key-three', 'key-one']);
});

test('missing/duplicate keys are never selected', () => {
  const keys = activeGeminiKeys((name) => ({
    GEMINI_API_KEY_PRIMARY: ' key-one ',
    GEMINI_API_KEY_SECONDARY: 'key-one',
    GEMINI_API_KEY_TERTIARY: 'key-three',
  })[name]);
  assert.deepEqual(keys, ['key-one', 'key-three']);
  assert.equal(keyAtSlot(keys, 2), 'key-three');
});

test('invalid cursor values fail closed', () => {
  for (const slot of [0, 4, -1, NaN, 1.5]) {
    assert.throws(() => keyAtSlot(['a','b','c'], slot),
      /gemini_dispatch_unavailable/);
  }
});

import {candidateModels, classifyGeminiHttp, finalGeminiError, SAFE_DOCUMENT_MODEL}
  from './gemini_model_policy.ts';

test('legacy model IDs get a supported document fallback without duplicates', () => {
  assert.deepEqual(candidateModels(['models/gemini-2.5-flash', 'gemini-2.5-flash']),
    ['gemini-2.5-flash', SAFE_DOCUMENT_MODEL]);
  assert.deepEqual(candidateModels([null, '', SAFE_DOCUMENT_MODEL]), [SAFE_DOCUMENT_MODEL]);
});

test('404 and transient errors try another model but not another API key', () => {
  assert.equal(classifyGeminiHttp(404), 'next_model');
  assert.equal(classifyGeminiHttp(503), 'next_model');
  assert.equal(classifyGeminiHttp(408), 'next_model');
  assert.equal(classifyGeminiHttp(429), 'rate_limited');
  assert.equal(classifyGeminiHttp(400), 'configuration');
  assert.equal(classifyGeminiHttp(403), 'configuration');
  assert.equal(classifyGeminiHttp(402), 'configuration');
  assert.equal(finalGeminiError([404, 404]), 'gemini_model_unavailable');
  assert.equal(finalGeminiError([404, 503]), 'gemini_unavailable');
});
