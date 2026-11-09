"""Network helpers are exercised with fixtures; tests never contact lyrics/weather services."""
import importlib.machinery
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, urlsplit

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent.parent
loader = importlib.machinery.SourceFileLoader('online', str(ROOT / 'bin/penumbra-online'))
spec = importlib.util.spec_from_loader(loader.name, loader)
online = importlib.util.module_from_spec(spec)
loader.exec_module(online)


class Online(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.cache = patch.object(online, 'CACHE', Path(self.temp.name))
        self.cache.start()
        self.addCleanup(self.cache.stop)

    def response(self, value):
        return io.BytesIO(json.dumps(value).encode())

    def test_lyrics_encoded_and_cached(self):
        with patch.object(online, 'urlopen', return_value=self.response({'syncedLyrics': '[00:01.25]a', 'plainLyrics': 'a'})) as request:
            first = online.main(['lyrics', 'A & B', 'Étoile', 'An album', '123'])
            self.assertEqual(first['synced'], '[00:01.25]a')
            self.assertEqual(online.main(['lyrics', 'A & B', 'Étoile', 'An album', '123']), first)
            request.assert_called_once()
            query = parse_qs(urlsplit(request.call_args.args[0].full_url).query)
            self.assertEqual(query['track_name'], ['A & B'])
            self.assertEqual(query['artist_name'], ['Étoile'])
            self.assertEqual(query['duration'], ['123'])
            self.assertEqual(request.call_args.kwargs['timeout'], 8)

    def test_missing_lyrics_and_instrumental(self):
        error = HTTPError('https://lrclib.net', 404, 'Not found', {}, None)
        self.addCleanup(error.close)
        with patch.object(online, 'urlopen', side_effect=error) as request:
            self.assertEqual(online.main(['lyrics', 'missing', 'artist', '', '0'])['status'], 'missing')
            online.main(['lyrics', 'missing', 'artist', '', '0'])
            request.assert_called_once()
        with patch.object(online, 'urlopen', return_value=self.response({'instrumental': True})):
            self.assertTrue(online.main(['lyrics', 'instrumental', 'artist', '', '0'])['instrumental'])

    def test_rate_limit_applies_across_tracks(self):
        error = HTTPError('https://lrclib.net', 429, 'Slow down', {'Retry-After': '3600'}, None)
        self.addCleanup(error.close)
        with patch.object(online.time, 'time', return_value=1000), patch.object(online, 'urlopen', side_effect=error) as request:
            online.main(['lyrics', 'one', 'artist', '', '0'])
            online.main(['lyrics', 'two', 'artist', '', '0'])
            request.assert_called_once()
            self.assertGreaterEqual(online.read(online.CACHE / 'lyrics/retry.json')['until'], 4600)

    def test_weather_expiry_and_stale_offline(self):
        value = {'current': {'temperature_2m': 15.2, 'apparent_temperature': 14, 'weather_code': 3, 'wind_speed_10m': 8, 'is_day': 1}}
        args = ['weather', '48.86', '2.33']
        with patch.object(online.time, 'time', return_value=10000), patch.object(online, 'urlopen', return_value=self.response(value)):
            self.assertEqual(online.main(args)['current']['temperature_2m'], 15.2)
        with patch.object(online.time, 'time', return_value=11000), patch.object(online, 'urlopen') as request:
            online.main(args)
            request.assert_not_called()
        with patch.object(online.time, 'time', return_value=12000), patch.object(online, 'urlopen', side_effect=URLError('offline')):
            self.assertTrue(online.main(args)['stale'])
        with patch.object(online.time, 'time', return_value=100000), patch.object(online, 'urlopen', side_effect=URLError('offline')):
            self.assertEqual(online.main(args)['status'], 'offline')

    def test_invalid_coordinates_never_request(self):
        with patch.object(online, 'urlopen') as request:
            for coords in [('91', '0'), ('0', '181'), ('nan', '0')]:
                with self.assertRaises(ValueError):
                    online.main(['weather', *coords])
            request.assert_not_called()

    def test_bad_payload_and_corrupt_cache(self):
        with patch.object(online, 'urlopen', return_value=self.response({'current': {'temperature_2m': None}})):
            self.assertEqual(online.main(['weather', '0', '0'])['status'], 'offline')
        p = online.CACHE / 'broken.json'
        for text in ['{', '[]', 'null']:
            p.write_text(text)
            self.assertEqual(online.read(p), {})
        self.assertEqual(online.retry_after('Tue, 03 Nov 2026 12:00:00 GMT', 0), 1793707200)


if __name__ == '__main__':
    unittest.main()
