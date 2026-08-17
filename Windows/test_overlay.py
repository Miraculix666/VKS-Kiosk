import unittest
from unittest.mock import patch, mock_open
import sys
import os

sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))
import overlay

class TestOverlay(unittest.TestCase):
    def setUp(self):
        overlay.last_mtime = None
        overlay.cached_text = "keine Datei"

    @patch('os.path.getmtime')
    @patch('builtins.open', new_callable=mock_open, read_data="v1.0")
    def test_read_text_success(self, mock_file, mock_getmtime):
        mock_getmtime.return_value = 1000.0
        result = overlay.read_text()
        self.assertEqual(result, "v1.0")
        mock_file.assert_called_once_with(overlay.TEXT_FILE)

    @patch('os.path.getmtime')
    @patch('builtins.open', side_effect=IOError)
    def test_read_text_error(self, mock_file, mock_getmtime):
        mock_getmtime.return_value = 1000.0
        result = overlay.read_text()
        self.assertEqual(result, "keine Datei")
        mock_file.assert_called_once_with(overlay.TEXT_FILE)

    @patch('os.path.getmtime')
    @patch('builtins.open', new_callable=mock_open, read_data="v1.0")
    def test_read_text_caching(self, mock_file, mock_getmtime):
        # Initial read
        mock_getmtime.return_value = 1000.0
        result1 = overlay.read_text()
        self.assertEqual(result1, "v1.0")
        self.assertEqual(mock_file.call_count, 1)

        # Second read, mtime unchanged -> should not open file again
        result2 = overlay.read_text()
        self.assertEqual(result2, "v1.0")
        self.assertEqual(mock_file.call_count, 1)

        # Third read, mtime changed -> should open file again
        mock_getmtime.return_value = 2000.0
        mock_file.return_value.read.return_value = "v2.0"
        result3 = overlay.read_text()
        self.assertEqual(result3, "v2.0")
        self.assertEqual(mock_file.call_count, 2)

if __name__ == '__main__':
    unittest.main()
