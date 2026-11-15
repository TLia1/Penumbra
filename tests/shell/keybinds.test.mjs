import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
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
        { key: 'F1', description: 'Help', dispatcher: 'spawn', arg: 'help' },
        { key: 'F1', dispatcher: 'exec', arg: 'custom-help', submap: 'resize', repeat: true },
        { key: 'F2', dispatcher: 'toggleoverview', release: true, locked: true },
        { key: 'F3', description: 'Disabled', enabled: false }
    ]);
    assert.equal(entries.length, 3);
    assert.equal(entries[0].action, 'Help');
    assert.equal(entries[1].action, 'exec custom-help');
    assert.match(entries[1].details, /Submap: resize.*Repeats/);
    assert.equal(entries[2].action, 'toggleoverview');
    assert.match(entries[2].details, /On release.*locked/);
    assert.equal(K.filter(entries, ' RESIZE f1 ').length, 1);
    assert.equal(K.filter(entries, 'missing').length, 0);
    assert.equal(K.filter(entries, '').length, 3);
    assert.throws(() => K.entries({ error: 'unavailable' }));
});

test('MangoWM config bindings parse with descriptions and readable shortcuts', () => {
    const mangoDir = new URL('../../config/mango/', import.meta.url);
    const text = ['config.conf', 'input.conf', 'keybinds.conf']
        .map(name => fs.readFileSync(fileURLToPath(new URL(name, mangoDir)), 'utf8'))
        .join('\n');
    const entries = K.entries(K.parseMangoConfig(text));
    assert.ok(entries.length >= 40);
    assert.ok(entries.some(e => e.keys === 'Super + Enter' && e.action === 'Open terminal'));
    assert.ok(entries.some(e => e.keys === 'Super + Number row 1' && e.action === 'Switch to workspace 1'));
    assert.ok(entries.some(e => e.keys === 'Super + Ctrl + Number row 1' && e.action === 'Toggle multi-tag view for tag 1'));
    assert.ok(entries.some(e => e.keys === 'Super + Left mouse' && e.action === 'Drag window'));
    assert.ok(entries.some(e => e.keys === 'Super + Scroll down' && e.action === 'Next workspace'));
    assert.ok(entries.some(e => e.keys === '4-finger swipe up' && e.action === 'Workspace overview'));
    assert.ok(entries.some(e => e.keys === 'Esc' && e.details.includes('Submap: resize')));
});
