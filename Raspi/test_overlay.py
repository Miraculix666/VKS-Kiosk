import unittest
from unittest.mock import patch, mock_open
import sys
import os

# Adjust path so we can import overlay from the Raspi directory without issues
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import overlay

class TestOverlay(unittest.TestCase):
    def test_read_text_success(self):
        # Test scenario 1: file is read successfully and returns trimmed content.
        mocked_file_content = "   Test Version 1.0.0   \n"
        with patch('builtins.open', mock_open(read_data=mocked_file_content)):
            result = overlay.read_text()
            self.assertEqual(result, "Test Version 1.0.0")

    def test_read_text_exception(self):
        # Test scenario 2: an exception occurs (e.g. file not found) and returns "keine Datei".
        with patch('builtins.open', side_effect=FileNotFoundError):
            result = overlay.read_text()
            self.assertEqual(result, "keine Datei")

if __name__ == '__main__':
    unittest.main()
