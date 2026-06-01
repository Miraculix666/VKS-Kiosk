import unittest
from unittest.mock import patch, mock_open
import sys
import os

# Add Raspi dir to path to import overlay
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import overlay

class TestOverlay(unittest.TestCase):

    @patch("builtins.open", new_callable=mock_open, read_data="  1.0.4 \n ")
    def test_read_text_success(self, mock_file):
        result = overlay.read_text()
        self.assertEqual(result, "1.0.4")
        mock_file.assert_called_once_with("/scripts/version.txt")

    @patch("builtins.open")
    def test_read_text_exception(self, mock_file):
        mock_file.side_effect = FileNotFoundError("File not found")
        result = overlay.read_text()
        self.assertEqual(result, "keine Datei")
        mock_file.assert_called_once_with("/scripts/version.txt")

if __name__ == '__main__':
    unittest.main()
