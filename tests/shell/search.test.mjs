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
    assert.equal(S.score(app('Files'), '', 0), 1);
});

test('use lifts an app, never by more than 15', () => {
    const lift = uses => S.score(app('Firefox'), 'fire', uses) - S.score(app('Firefox'), 'fire', 0);
    assert.ok(lift(5) > 9 && lift(5) < 10);
    assert.ok(lift(99) > lift(30) && lift(99) <= 15);
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

test('frecency halves every half-life and counts old launch totals as recent', () => {
    const day = 86400000, now = 100 * day;
    assert.equal(S.frecency(null, now), 0);
    assert.equal(S.frecency(40, now), 15);
    assert.equal(S.frecency({ score: 8, at: now - S.halfLife * day }, now), 4);
    const once = S.launched(undefined, now);
    assert.deepEqual(JSON.parse(JSON.stringify(once)), { score: 1, at: now });
    assert.equal(S.launched({ score: 2, at: now - S.halfLife * day }, now).score, 2);
});

test('frecency lifts matches without a cap where apps tie', () => {
    assert.ok(S.boost(20) > S.boost(15));
    assert.ok(S.boost(1000) <= 15);
    const often = S.score(app('Files'), 'fi', 12), seldom = S.score(app('Firefox'), 'fi', 1);
    assert.ok(often > seldom);
});

test('desktop actions match on the app and action names', () => {
    assert.equal(S.actionScore('Firefox', 'New Private Window', 'private'), 60);
    assert.equal(S.actionScore('Firefox', 'New Private Window', 'firefox private'), 45);
    assert.equal(S.actionScore('Firefox', 'New Private Window', 'pr'), 0);
    assert.equal(S.actionScore('Firefox', 'New Private Window', 'chrome'), 0);
});

test('units convert within a kind', () => {
    assert.deepEqual({ ...S.convert('10 km in mi') }, { value: 6.21371, unit: 'mi' });
    assert.deepEqual({ ...S.convert('100 c to f') }, { value: 212, unit: '°F' });
    assert.deepEqual({ ...S.convert('1 GiB in MB') }, { value: 1073.74, unit: 'MB' });
    assert.deepEqual({ ...S.convert('2,5 kg to lb') }, { value: 5.51156, unit: 'lb' });
    assert.equal(S.convert('10 km in kg'), null);
    assert.equal(S.convert('firefox'), null);
});

test('currency queries name two currencies', () => {
    assert.deepEqual({ ...S.currency('100 usd in eur') }, { amount: 100, from: 'USD', to: 'EUR' });
    assert.deepEqual({ ...S.currency('20€ to $') }, { amount: 20, from: 'EUR', to: 'USD' });
    assert.equal(S.currency('100 in eur'), null);
    assert.equal(S.currency('10 km in mi'), null);
    assert.equal(S.currency('5 eur to eur'), null);
});
