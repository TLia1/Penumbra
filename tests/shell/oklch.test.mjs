// The shell's OKLCH conversions (oklch.js); test_shell.py compares them with palette.py's.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { load } from './load.mjs';

const O = load('oklch.js');

test('hex round trips through OKLCH', () => {
    for (const hex of ['#000000', '#ffffff', '#7c5cff', '#e8e0ff', '#1b1830', '#ff0000']) {
        const [L, C, H] = O.fromHex(hex);
        assert.equal(O.color(L, C, H), hex);
    }
});

test('colours out of gamut keep lightness and hue', () => {
    const hex = O.color(0.7, 0.5, 300);
    assert.match(hex, /^#[0-9a-f]{6}$/);
    const [L, , H] = O.fromHex(hex);
    assert.ok(Math.abs(L - 0.7) < 0.01 && Math.abs(H - 300) < 2, `${hex}: ${L} ${H}`);
});

test('short and bare hex are accepted, anything else is not', () => {
    assert.deepEqual(O.fromHex('fff'), O.fromHex('#ffffff'));
    assert.equal(O.fromHex('#12345'), null);
    assert.equal(O.fromHex('violet'), null);
});
