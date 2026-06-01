import unittest
from unittest.mock import patch, mock_open
import os
import sys

# Ensure Linux directory is in the path to import overlay.py
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))
import overlay

class TestOverlay(unittest.TestCase):
    @patch('builtins.open', new_callable=mock_open, read_data="v1.2.3\n")
    def test_read_text_success(self, mock_file):
        """Test read_text when the file exists and contains text."""
        result = overlay.read_text()
        self.assertEqual(result, "v1.2.3")
        mock_file.assert_called_once_with(overlay.TEXT_FILE)

    @patch('builtins.open')
    def test_read_text_failure(self, mock_file):
        """Test read_text when the file does not exist or cannot be read."""
        mock_file.side_effect = FileNotFoundError
        result = overlay.read_text()
        self.assertEqual(result, "keine Datei")
        mock_file.assert_called_once_with(overlay.TEXT_FILE)

if __name__ == '__main__':
    unittest.main()
