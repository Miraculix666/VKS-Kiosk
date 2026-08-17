import unittest
from unittest.mock import patch, mock_open
import sys
import os

sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))
import overlay

class TestOverlay(unittest.TestCase):
    @patch('builtins.open', new_callable=mock_open, read_data="v1.0")
    def test_read_text_success(self, mock_file):
        result = overlay.read_text()
        self.assertEqual(result, "v1.0")
        mock_file.assert_called_once_with(overlay.TEXT_FILE)

    @patch('builtins.open', side_effect=FileNotFoundError)
    def test_read_text_error(self, mock_file):
        result = overlay.read_text()
        self.assertEqual(result, "keine Datei")
        mock_file.assert_called_once_with(overlay.TEXT_FILE)

if __name__ == '__main__':
    unittest.main()
