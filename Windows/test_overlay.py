import unittest
from unittest.mock import mock_open, patch
import os
import sys

# Ensure Windows/ is in sys.path so we can import overlay
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import overlay

class TestOverlay(unittest.TestCase):
    def test_read_text_success(self):
        # Mock open to return a successful file read
        mock_file_content = "v1.2.3  "
        with patch('builtins.open', mock_open(read_data=mock_file_content)):
            result = overlay.read_text()
            self.assertEqual(result, "v1.2.3")

    def test_read_text_failure(self):
        # Mock open to raise an exception, simulating a missing file or error
        with patch('builtins.open', side_effect=Exception("File not found")):
            result = overlay.read_text()
            self.assertEqual(result, "keine Datei")

if __name__ == '__main__':
    unittest.main()
