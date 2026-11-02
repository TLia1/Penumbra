// The launcher's matching and calculator (search.js).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { load } from './load.mjs';

const S = load('search.js');
const app = (name, more = {}) => ({ name, id: name.toLowerCase(), genericName: '', keywords: [], comment: '', ...more });

test('sums are worked out', () => {
    assert.equal(S.calculate('2+2'), 4);
    assert.equal(S.calculate('2^10'), 1024);
    assert.equal(S.calculate('3,5*2'), 7);
    assert.equal(S.calculate('sqrt(16)'), 4);
    assert.equal(S.calculate('max(1,5)'), 5);
    assert.equal(S.calculate('0.1+0.2'), 0.3);
    assert.equal(S.calculate('=12'), 12);
    assert.equal(S.calculate('-3*2'), -6);
});

test('anything that is not a sum is a search', () => {
    assert.equal(S.calculate('42'), null);           // a bare number
    assert.equal(S.calculate('firefox'), null);
    assert.equal(S.calculate('1/0'), null);          // not finite
    assert.equal(S.calculate('2+'), null);           // not valid
    assert.equal(S.calculate('alert(1)+1'), null);   // not a Math name
    assert.equal(S.calculate('constructor(1)+1'), null);
    assert.equal(S.calculate('this.x+1'), null);     // a dot after a word is not arithmetic
});

test('names rank exact, then prefix, then word, then inside, then scattered', () => {
    const q = 'fire';
    const ranks = [app('Fire'), app('Firefox'), app('Sky Fire'), app('Campfire'), app('Fixed Ire')].map(a => S.score(a, q, 0));
    assert.deepEqual([...ranks].sort((a, b) => b - a), ranks);
    assert.ok(ranks.every(r => r > 0));
});

test('descriptions match last, and nothing matches nothing', () => {
    assert.equal(S.score(app('Files', { genericName: 'File Manager' }), 'manager', 0), 25);
    assert.equal(S.score(app('Files'), 'zzz', 0), 0);
    assert.equal(S.score(app('Files'), '', 3), 4);
});

test('use lifts an app, up to a cap', () => {
    assert.equal(S.score(app('Firefox'), 'fire', 5) - S.score(app('Firefox'), 'fire', 0), 5);
    assert.equal(S.score(app('Firefox'), 'fire', 99) - S.score(app('Firefox'), 'fire', 0), 15);
});

test('fuzzy matches favour fewer gaps', () => {
    assert.ok(S.fuzzy('thunderbird', 'tbd') > 0);
    assert.ok(S.fuzzy('abc', 'abc') > S.fuzzy('axbxc', 'abc'));
    assert.equal(S.fuzzy('abc', 'cba'), 0);
});

test('characters match every term, names before groups', () => {
    const heart = { char: '❤', name: 'red heart', group: 'Smileys & Emotion' };
    assert.equal(S.charScore(heart, ['red', 'heart'], 0), 100);
    assert.equal(S.charScore(heart, ['heart'], 0), 40);
    assert.equal(S.charScore(heart, ['smileys'], 0), 10);
    assert.equal(S.charScore(heart, ['blue'], 0), 0);
    assert.equal(S.charScore(heart, [], 50), 41);
});
