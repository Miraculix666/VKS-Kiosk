import unittest
from unittest.mock import patch, mock_open
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))
import overlay

class TestOverlay(unittest.TestCase):
    def setUp(self):
        overlay.last_mtime = None
        overlay.cached_text = "keine Datei"

    @patch('os.path.getmtime')
    @patch('builtins.open', new_callable=mock_open, read_data="v1.2.3\n")
    def test_read_text_success(self, mock_file, mock_getmtime):
        """Test read_text when the file exists and contains text."""
        mock_getmtime.return_value = 1000
        result = overlay.read_text()
        self.assertEqual(result, "v1.2.3")
        mock_getmtime.assert_called_once_with(overlay.TEXT_FILE)
        mock_file.assert_called_once_with(overlay.TEXT_FILE)

    @patch('os.path.getmtime')
    @patch('builtins.open')
    def test_read_text_failure(self, mock_file, mock_getmtime):
        """Test read_text when the file does not exist or cannot be read."""
        mock_getmtime.side_effect = FileNotFoundError
        result = overlay.read_text()
        self.assertEqual(result, "keine Datei")
        mock_getmtime.assert_called_once_with(overlay.TEXT_FILE)
        mock_file.assert_not_called()

if __name__ == '__main__':
    unittest.main()
