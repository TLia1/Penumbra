"""Run the Penumbra test suite: `python3 tests` or `python3 tests/`."""
from pathlib import Path
import sys
import unittest

sys.dont_write_bytecode = True
suite = unittest.defaultTestLoader.discover(str(Path(__file__).resolve().parent))
sys.exit(0 if unittest.TextTestRunner(verbosity=2).run(suite).wasSuccessful() else 1)
