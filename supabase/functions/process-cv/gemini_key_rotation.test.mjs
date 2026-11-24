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
