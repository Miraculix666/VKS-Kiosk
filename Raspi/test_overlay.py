import unittest
from unittest.mock import patch, mock_open
import sys
import os

sys.path.insert(0, os.path.dirname(__file__))

import overlay

class TestOverlay(unittest.TestCase):
    @patch('builtins.open', new_callable=mock_open, read_data='1.0.0\n')
    def test_read_text_success(self, mock_file):
        """Test read_text when the file exists and contains text."""
        result = overlay.read_text()
        self.assertEqual(result, '1.0.0')
        mock_file.assert_called_once_with(overlay.TEXT_FILE)

    @patch('builtins.open', side_effect=FileNotFoundError)
    def test_read_text_file_not_found(self, mock_file):
        """Test read_text when the file does not exist."""
        result = overlay.read_text()
        self.assertEqual(result, 'keine Datei')
        mock_file.assert_called_once_with(overlay.TEXT_FILE)

if __name__ == '__main__':
    unittest.main()
