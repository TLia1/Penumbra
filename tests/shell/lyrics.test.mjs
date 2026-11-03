import { test } from 'node:test';
import assert from 'node:assert/strict';
import { load } from './load.mjs';
const Lrc = load('lyrics.js');
const Sun = load('sun.js');

test('LRC sorts repeated stamps, applies offsets and ignores metadata', () => {
    const rows = Lrc.parse('[ar:Someone]\n[offset:-250]\n[00:20.5][00:40.050]Again\n[00:01.250]First\n[00:25.00]\ninvalid');
    assert.deepEqual(Array.from(rows, r => [r.time, r.text]), [[1, 'First'], [20.25, 'Again'], [24.75, ''], [39.8, 'Again']]);
});
test('LRC cursor handles intro, exact timestamps and backwards seeks', () => {
    const rows = Lrc.parse('[00:10]First\n[00:20]Next');
    assert.equal(Lrc.current(rows, 0), -1);
    assert.equal(Lrc.current(rows, 10), 0);
    assert.equal(Lrc.current(rows, 200), 1);
    assert.equal(Lrc.current(rows, 15), 0);
    assert.equal(Lrc.current([], 100), -1);
});
test('lunar model recognises the April 2024 new and full moons', () => {
    const eclipse = Sun.moon(new Date('2024-04-08T18:21:00Z'));
    assert.equal(eclipse.name, 'New moon');
    assert.ok(eclipse.illumination < 0.01);
    const full = Sun.moon(new Date('2024-04-23T23:49:00Z'));
    assert.equal(full.name, 'Full moon');
    assert.ok(full.illumination > 0.99);
    for (let d = 1; d <= 30; d++) {
        const m = Sun.moon(new Date(Date.UTC(2026, 10, d)));
        assert.ok(m.phase >= 0 && m.phase < 1);
        assert.ok(m.illumination >= 0 && m.illumination <= 1);
    }
});
