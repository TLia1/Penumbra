import { test } from 'node:test';
import assert from 'node:assert/strict';
import { load } from './load.mjs';

const { videoId } = load('youtube.js');
const id = 'AB_12-cd345';

test('extracts the current video without playlist or playback parameters', () => {
    for (const url of [
        'https://www.youtube.com/watch?v=' + id + '&list=PL123',
        'https://music.youtube.com/watch?list=PL123&v=' + id,
        'https://youtu.be/' + id + '?t=42',
        'https://m.youtube.com/shorts/' + id,
        'https://www.youtube.com/live/' + id + '#chat',
        'https://www.youtube.com/embed/' + id,
    ]) assert.equal(videoId(url), id);
});

test('unrelated media and invalid IDs cannot trigger YouTube requests', () => {
    for (const url of [
        undefined, 'file:///music/song.ogg', 'https://www.youtube.com/playlist?list=' + id,
        'https://youtube.com.example.org/watch?v=' + id, 'https://example.org/?v=' + id,
        'https://youtu.be/' + id + 'x', 'https://youtube.com/watch#?v=' + id,
    ]) assert.equal(videoId(url), '');
});
