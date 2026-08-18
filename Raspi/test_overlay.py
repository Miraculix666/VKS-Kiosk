import unittest
from unittest.mock import patch, mock_open
import sys
import os

# Adjust path so we can import overlay from the Raspi directory without issues
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import overlay

class TestOverlay(unittest.TestCase):
    def setUp(self):
        overlay.last_mtime = None
        overlay.cached_text = "keine Datei"

    @patch('os.path.getmtime')
    def test_read_text_success(self, mock_getmtime):
        mock_getmtime.return_value = 1000
        mocked_file_content = "   Test Version 1.0.0   \n"
        with patch('builtins.open', mock_open(read_data=mocked_file_content)):
            result = overlay.read_text()
            self.assertEqual(result, "Test Version 1.0.0")
            self.assertEqual(overlay.last_mtime, 1000)

    def test_read_text_exception(self):
        # Test scenario 2: an exception occurs (e.g. file not found) and returns "keine Datei".
        with patch('builtins.open', side_effect=FileNotFoundError()):
            result = overlay.read_text()
            self.assertEqual(result, "keine Datei")

if __name__ == '__main__':
    unittest.main()
