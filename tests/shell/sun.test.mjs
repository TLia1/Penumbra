// Night light's sunrise and sunset, and its schedule arithmetic (sun.js).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { load } from './load.mjs';

const Sun = load('sun.js');

test('times parse and print', () => {
    assert.equal(Sun.minutes('21:30'), 1290);
    assert.equal(Sun.minutes(' 7:05 '), 425);
    assert.equal(Sun.minutes('24:00'), -1);
    assert.equal(Sun.minutes('nine'), -1);
    assert.equal(Sun.clock(1290), '21:30');
    assert.equal(Sun.clock(-30), '23:30');
    assert.equal(Sun.clock(1440 + 5), '00:05');
});

test('schedules work across midnight', () => {
    assert.ok(Sun.between(22 * 60, 21 * 60, 7 * 60));
    assert.ok(Sun.between(6 * 60, 21 * 60, 7 * 60));
    assert.ok(!Sun.between(12 * 60, 21 * 60, 7 * 60));
    assert.ok(Sun.between(12 * 60, 9 * 60, 17 * 60));
    assert.ok(!Sun.between(17 * 60, 9 * 60, 17 * 60));
});

test('zone1970.tab coordinates', () => {
    const paris = Sun.coordinates('+4852+00220');
    assert.ok(Math.abs(paris.latitude - 48.8667) < 1e-3 && Math.abs(paris.longitude - 2.3333) < 1e-3);
    const ny = Sun.coordinates('+404251-0740023');
    assert.ok(Math.abs(ny.latitude - 40.7142) < 1e-3 && Math.abs(ny.longitude + 74.0064) < 1e-3);
    assert.equal(Sun.coordinates('Paris'), null);
});

test('the sun at the equinox rises and sets about twelve hours apart', () => {
    // Day lengths don't depend on the time zone the test runs in; rise and set times do.
    const t = Sun.times(new Date(2026, 2, 20), 0, 0);
    assert.ok(!t.polar);
    const length = (t.set - t.rise + 1440) % 1440;
    assert.ok(Math.abs(length - 12 * 60 - 7) < 6, `day length ${length}`);
});

test('polar day and night', () => {
    assert.equal(Sun.times(new Date(2026, 5, 21), 78, 15).polar, 'day');
    assert.equal(Sun.times(new Date(2026, 11, 21), 78, 15).polar, 'night');
});
