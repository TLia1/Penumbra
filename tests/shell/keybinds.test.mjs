import { test } from 'node:test';
import assert from 'node:assert/strict';
import { load } from './load.mjs';

const K = load('keybinds.js');

test('physical workspace keys remain readable across keyboard layouts', () => {
    assert.equal(K.shortcut({ modmask: 65, keycode: 10 }), 'Super + Shift + Number row 1');
    assert.equal(K.shortcut({ modmask: 72, keycode: 19 }), 'Super + Alt + Number row 0');
    assert.equal(K.shortcut({ modmask: 64, keycode: 49 }), 'Super + Key left of 1');
    assert.equal(K.shortcut({ keycode: 99 }), 'Keycode 99');
});

test('mouse, media and punctuation bindings have readable names', () => {
    assert.equal(K.shortcut({ modmask: 64, key: 'mouse:272' }), 'Super + Left mouse');
    assert.equal(K.shortcut({ modmask: 64, key: 'comma' }), 'Super + ,');
    assert.equal(K.shortcut({ key: 'XF86AudioMicMute' }), 'Microphone mute');
});

test('active custom bindings, submaps and duplicate chords are preserved', () => {
    const entries = K.entries([
        { key: 'F1', description: 'Help', dispatcher: '__lua', arg: '12' },
        { key: 'F1', dispatcher: 'exec', arg: 'custom-help', submap: 'resize', repeat: true },
        { key: 'F2', dispatcher: '__lua', arg: '13', release: true, locked: true },
        { key: 'F3', description: 'Disabled', enabled: false }
    ]);
    assert.equal(entries.length, 3);
    assert.equal(entries[0].action, 'Help');
    assert.equal(entries[1].action, 'exec custom-help');
    assert.match(entries[1].details, /Submap: resize.*Repeats/);
    assert.equal(entries[2].action, 'Custom Lua binding (no description)');
    assert.match(entries[2].details, /On release.*locked/);
    assert.equal(K.filter(entries, ' RESIZE f1 ').length, 1);
    assert.equal(K.filter(entries, 'missing').length, 0);
    assert.equal(K.filter(entries, '').length, 3);
    assert.throws(() => K.entries({ error: 'unavailable' }));
});
