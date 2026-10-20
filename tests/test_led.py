import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('led', Path(__file__).parents[1] / 'led.py')
led = importlib.util.module_from_spec(spec)
spec.loader.exec_module(led)

class LedTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.device = Path(self.temp.name)
        for name, value in {'multi_index': 'blue red green', 'multi_intensity': '100 100 100',
                            'multi_max_intensity': '255 255 255', 'brightness': '100',
                            'max_brightness': '255'}.items():
            (self.device / name).write_text(value + '\n')

    def test_order_is_discovered(self):
        result = led.apply(['200', '110', '120', '130'], self.device)
        self.assertEqual(result['rgb'], {'red': 110, 'green': 120, 'blue': 130})
        self.assertEqual((self.device / 'multi_intensity').read_text(), '130 110 120\n')
        self.assertEqual(result['brightness'], 200)

    def test_rejects_invalid_before_writing(self):
        for values in [['256', '0', '0', '0'], ['1', '256', '0', '0'],
                       ['1', '-1', '0', '0'], ['1', '1.2', '0', '0'],
                       ['1', '0; id', '0', '0'], ['1'], ['1', '١', '0', '0']]:
            with self.subTest(values=values), self.assertRaises(ValueError):
                led.apply(values, self.device)
            self.assertEqual((self.device / 'brightness').read_text(), '100\n')
            self.assertEqual((self.device / 'multi_intensity').read_text(), '100 100 100\n')

    def test_missing_support_fails_closed(self):
        (self.device / 'multi_max_intensity').unlink()
        with self.assertRaises(OSError):
            led.apply(['1', '1', '1', '1'], self.device)
        self.assertEqual((self.device / 'brightness').read_text(), '100\n')

    def test_unknown_layout_fails_closed(self):
        (self.device / 'multi_index').write_text('red red blue')
        with self.assertRaises(ValueError):
            led.state(self.device)

    def test_channel_specific_limits(self):
        (self.device / 'multi_max_intensity').write_text('200 150 255')
        with self.assertRaises(ValueError):
            led.apply(['100', '151', '100', '100'], self.device)

if __name__ == '__main__':
    unittest.main()
