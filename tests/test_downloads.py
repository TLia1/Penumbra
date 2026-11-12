"""Video and audio downloads (bin/penumbra-download and the Downloads panel)."""
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('downloads', str(ROOT / 'bin/penumbra-download'))
spec = importlib.util.spec_from_loader(loader.name, loader)
dl = importlib.util.module_from_spec(spec)
loader.exec_module(dl)


class Downloads(unittest.TestCase):
    def test_video_and_audio_options(self):
        files = Path('/tmp/files')
        mp4 = dl.ytdlp_options(False, 'mp4', '1080', Path('/v'), False, files)
        self.assertIn('--no-playlist', mp4)
        self.assertIn('--embed-thumbnail', mp4)
        self.assertEqual(mp4[mp4.index('-S') + 1], 'res:1080,ext:mp4:m4a')
        self.assertEqual(mp4[mp4.index('--merge-output-format') + 1], 'mp4')

        mkv = dl.ytdlp_options(False, 'mkv', 'best', Path('/v'), True, files)
        self.assertIn('--yes-playlist', mkv)
        self.assertNotIn('-S', mkv)
        self.assertEqual(mkv[mkv.index('--merge-output-format') + 1], 'mkv')

        webm = dl.ytdlp_options(False, 'webm', '720', Path('/v'), False, files)
        self.assertNotIn('--embed-thumbnail', webm)
        self.assertEqual(webm[webm.index('--recode-video') + 1], 'webm')

        mp3 = dl.ytdlp_options(True, 'mp3', '192', Path('/m'), False, files)
        self.assertIn('-x', mp3)
        self.assertIn('--embed-thumbnail', mp3)
        self.assertEqual(mp3[mp3.index('--audio-format') + 1], 'mp3')
        self.assertEqual(mp3[mp3.index('--audio-quality') + 1], '192K')

        flac = dl.ytdlp_options(True, 'flac', '192', Path('/m'), False, files)
        self.assertNotIn('--audio-quality', flac)
        self.assertNotIn('--embed-thumbnail', flac)

        with self.assertRaises(ValueError):
            dl.ytdlp_options(False, 'avi', 'best', Path('/v'), False, files)
        with self.assertRaises(ValueError):
            dl.ytdlp_options(False, 'mp4', '999', Path('/v'), False, files)
        with self.assertRaises(ValueError):
            dl.ytdlp_options(True, 'mp3', '64', Path('/m'), False, files)

    def test_progress_and_errors(self):
        progress = dl.parse_progress('@@ downloading 500000 1000000 NA 250000 2 1 3 A video title\n')
        self.assertEqual(progress, {
            'status': 'downloading', 'done': 500000.0, 'size': 1000000.0, 'percent': 50.0,
            'speed': 250000.0, 'eta': 2, 'item': 1, 'items': 3, 'title': 'A video title',
        })
        unknown = dl.parse_progress('@@ downloading 1024 NA NA NA NA NA NA NA\n')
        self.assertEqual(unknown['percent'], -1)
        self.assertEqual(unknown['title'], '')
        self.assertIsNone(dl.parse_progress('[download] 50% of 1.00MiB\n'))
        self.assertEqual(dl.error_line('WARNING: x\nERROR: [youtube] abc: Private video\n'), 'Private video')

    def test_summarize_video_portrait_and_playlist(self):
        video = dl.summarize({
            'title': 'Vertical', 'uploader': 'Channel', 'duration': 90, 'thumbnail': 'https://img/1.jpg',
            'formats': [
                {'height': 1920, 'width': 1080, 'vcodec': 'avc1'},
                {'height': 1280, 'width': 720, 'vcodec': 'avc1'},
                {'height': 1080, 'vcodec': 'none'},
            ],
        })
        self.assertEqual(video['heights'], [1080, 720])
        self.assertFalse(video['audioOnly'])

        playlist = dl.summarize({
            '_type': 'playlist', 'title': 'Mix', 'entries': [{'duration': 60}, {'duration': 120}],
            'thumbnails': [{'url': 'https://img/p.jpg'}],
        })
        self.assertEqual(playlist['kind'], 'playlist')
        self.assertEqual(playlist['entries'], 2)
        self.assertEqual(playlist['duration'], 180)

    def test_download_lifecycle_with_fake_ytdlp(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            bindir = root / 'bin'
            runtime = root / 'run'
            videos = root / 'Videos'
            bindir.mkdir()
            ytdlp = bindir / 'yt-dlp'
            ytdlp.write_text(
                '#!/usr/bin/env python3\n'
                'import json, pathlib, sys\n'
                'args = sys.argv[1:]\n'
                'if "--version" in args:\n'
                '    print("2026.11.01"); sys.exit(0)\n'
                'if "-J" in args:\n'
                '    print(json.dumps({"title": "Sample", "channel": "Penumbra", "duration": 42,\n'
                '                      "formats": [{"height": 1080, "width": 1920, "vcodec": "avc1"}]}))\n'
                '    sys.exit(0)\n'
                'folder = pathlib.Path(args[args.index("-P") + 1])\n'
                'files = pathlib.Path(args[args.index("--print-to-file") + 2])\n'
                'out = folder / "Sample.mp4"\n'
                'print("@@ downloading 500 1000 NA 500 1 NA NA Sample", flush=True)\n'
                'print("[Merger] Merging formats into \\"" + str(out) + "\\"", flush=True)\n'
                'out.write_bytes(b"video")\n'
                'files.write_text(str(out) + "\\n")\n'
            )
            ytdlp.chmod(ytdlp.stat().st_mode | stat.S_IEXEC)
            env = {**os.environ, 'PATH': f'{bindir}:{os.environ["PATH"]}',
                   'XDG_RUNTIME_DIR': str(runtime), 'HOME': str(root)}

            probed = json.loads(subprocess.check_output([str(ROOT / 'bin/penumbra-download'), 'probe'], env=env, text=True))
            self.assertEqual(probed['ytdlp'], '2026.11.01')
            self.assertEqual(probed['videos'], str(videos))

            looked = json.loads(subprocess.check_output([str(ROOT / 'bin/penumbra-download'), 'info', 'https://example.com/v'],
                                                        env=env, text=True))
            self.assertEqual(looked['title'], 'Sample')
            self.assertEqual(looked['heights'], [1080])

            subprocess.run([str(ROOT / 'bin/penumbra-download'), 'start', 'https://example.com/v',
                            '--format', 'mp4', '--quality', '1080', '--folder', str(videos), '--title', 'Sample'],
                           env=env, check=True)
            jobs = json.loads((runtime / 'penumbra/downloads').read_text())
            self.assertEqual(len(jobs), 1)
            self.assertEqual(jobs[0]['status'], 'done')
            self.assertEqual(jobs[0]['file'], str(videos / 'Sample.mp4'))
            self.assertTrue((videos / 'Sample.mp4').is_file())

            subprocess.run([str(ROOT / 'bin/penumbra-download'), 'forget'], env=env, check=True)
            self.assertEqual(json.loads((runtime / 'penumbra/downloads').read_text()), [])


if __name__ == '__main__':
    unittest.main()
