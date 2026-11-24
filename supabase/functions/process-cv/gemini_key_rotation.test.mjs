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

import {candidateModels, classifyGeminiHttp, finalGeminiError, SAFE_DOCUMENT_MODEL,
  SUPPORTED_DOCUMENT_FALLBACKS, listedContentModels, textGenerationModel,
  canRetryTransientStatus, transientBackoffMs,
  expectedGeminiShape} from './gemini_model_policy.ts';

test('legacy model IDs get a supported document fallback without duplicates', () => {
  assert.deepEqual(candidateModels(['models/gemini-2.5-flash', 'gemini-2.5-flash']),
    [...SUPPORTED_DOCUMENT_FALLBACKS]);
  assert.deepEqual(candidateModels([null, '', SAFE_DOCUMENT_MODEL]),
    [...SUPPORTED_DOCUMENT_FALLBACKS]);
  assert.deepEqual(candidateModels(['gemini-2.5-flash-lite'], null, 'ocr'),
    [SAFE_DOCUMENT_MODEL, 'gemini-3.8-flash','gemini-3.1-flash-lite',
      'gemini-3.6-flash']);
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

test('transient status retry is bounded and never retries credentials or quota', () => {
  assert.equal(canRetryTransientStatus(503), true);
  assert.equal(canRetryTransientStatus(502), true);
  assert.equal(canRetryTransientStatus(408), true);
  for (const status of [400, 401, 403, 404, 429]) {
    assert.equal(canRetryTransientStatus(status), false);
  }
  assert.equal(transientBackoffMs(0, 0), 800);
  assert.equal(transientBackoffMs(1, 0), 1600);
  assert.equal(transientBackoffMs(1, 1), 2000);
});

test('model schema failures never count as valid vacancy analysis', () => {
  assert.equal(expectedGeminiShape('job', {requirements:[]}), false);
  assert.equal(expectedGeminiShape('job', {requirements:[{},{}]}), true);
  assert.equal(expectedGeminiShape('job', {message:'Hello'}), false);
  assert.equal(expectedGeminiShape('job', []), false);
  const cv = {candidate:{skills:[],experience:[],education:[]},
    document:{raw_text:'real document'}, sections:{}};
  assert.equal(expectedGeminiShape('ocr',cv),true);
  assert.equal(expectedGeminiShape('ocr',{candidate:{},document:{}}),false);
});

test('model discovery filters uncallable, legacy and unrelated Gemini models', () => {
  const inventory = listedContentModels({models:[
    {name:'models/gemini-2.5-flash-lite',supportedGenerationMethods:['generateContent']},
    {name:'models/gemini-3.8-flash',supportedGenerationMethods:['generateContent']},
    {name:'models/gemini-3.5-flash-lite',supportedGenerationMethods:['generateContent']},
    {name:'models/gemini-3.8-flash-image',supportedGenerationMethods:['generateContent']},
    {name:'models/gemini-3.1-flash-lite',supportedGenerationMethods:['countTokens']},
    {name:'models/gemini-3.8-flash',supportedGenerationMethods:['generateContent']},
  ]});
  assert.deepEqual(inventory,['gemini-3.8-flash','gemini-3.5-flash-lite']);
  assert.deepEqual(candidateModels(['gemini-2.5-flash-lite'],inventory,'job'),
    ['gemini-3.8-flash','gemini-3.5-flash-lite']);
  assert.deepEqual(candidateModels(['gemini-3.6-flash'],inventory,'ocr'),
    ['gemini-3.5-flash-lite','gemini-3.8-flash']);
  assert.equal(textGenerationModel('gemini-2.5-flash-lite'),null);
  assert.equal(textGenerationModel('gemini-3.8-flash-image'),null);
  assert.deepEqual(listedContentModels({models:[]}),[]);
});
