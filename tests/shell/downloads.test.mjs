// The Downloads panel's pure logic (downloads.js).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { load } from './load.mjs';

const D = load('downloads.js');

test('addresses are recognised strictly in the launcher and loosely in the panel', () => {
    assert.equal(D.address('https://www.youtube.com/watch?v=abc', false), 'https://www.youtube.com/watch?v=abc');
    assert.equal(D.address('  http://localhost:8000/video.mp4 ', false), 'http://localhost:8000/video.mp4');
    assert.equal(D.address('youtube.com/watch?v=abc', false), '');
    assert.equal(D.address('youtube.com/watch?v=abc', true), 'https://youtube.com/watch?v=abc');
    assert.equal(D.address('two words', true), '');
    assert.equal(D.address('firefox', true), '');
    assert.equal(D.address('file:///etc/passwd', true), '');
    assert.equal(D.inPlaylist('https://www.youtube.com/watch?v=abc&list=PL123'), true);
    assert.equal(D.inPlaylist('https://www.youtube.com/watch?v=abc'), false);
});

test('formats and qualities adapt to video, audio, lossless and the video height', () => {
    assert.equal(D.format(false, ''), 'mp4');
    assert.equal(D.format(false, 'mkv'), 'mkv');
    assert.equal(D.format(false, 'mp3'), 'mp4');
    assert.equal(D.format(true, ''), 'mp3');
    assert.equal(D.format(true, 'flac'), 'flac');
    assert.equal(D.format(true, 'mp4'), 'mp3');

    const hd = Array.from(D.qualities(false, 'mp4', [1080, 720, 360]), q => q.value);
    assert.deepEqual(hd, ['best', '1080', '720', '480']);
    assert.equal(D.quality(D.qualities(false, 'mp4', [720]), '1080'), 'best');
    assert.equal(D.quality(D.qualities(false, 'mp4', [1080]), '720'), '720');
    assert.equal(D.qualities(true, 'flac', []).length, 0);
    assert.equal(D.qualities(true, 'wav', []).length, 0);
    assert.deepEqual(Array.from(D.qualities(true, 'mp3', []), q => q.value), ['best', '320', '192', '128']);
});

test('download commands carry the chosen options cleanly', () => {
    assert.deepEqual(Array.from(D.command('/bin/penumbra-download', {
        url: 'https://example.com/v', audio: true, format: 'opus', quality: '192',
        folder: '/home/lia/Music', playlist: true, title: 'Song'
    })), [
        '/bin/penumbra-download', 'start', 'https://example.com/v',
        '--format', 'opus', '--quality', '192', '--audio',
        '--folder', '/home/lia/Music', '--playlist', '--title', 'Song'
    ]);
});

test('sizes, times, paths and job descriptions', () => {
    assert.equal(D.bytes(0), '');
    assert.equal(D.bytes(512), '512 B');
    assert.equal(D.bytes(1500000), '1.5 MB');
    assert.equal(D.clock(75), '1:15');
    assert.equal(D.clock(3725), '1:02:05');
    assert.equal(D.home('/home/lia/Videos', '/home/lia'), '~/Videos');
    assert.equal(D.expand('~/Music', '/home/lia'), '/home/lia/Music');
    assert.equal(D.describe({
        status: 'downloading', percent: 42.8, size: 100000000, speed: 5000000, eta: 12, item: 2, items: 5
    }, '/home/lia'), '2 of 5 · 42% of 100 MB · 5.0 MB/s · 0:12 left');
    assert.equal(D.describe({
        status: 'done', file: '/home/lia/Videos/Clip.mp4', items: 1
    }, '/home/lia'), 'Saved in ~/Videos');
});
