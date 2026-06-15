import unittest
from unittest.mock import patch, mock_open
import sys
import os

sys.path.insert(0, os.path.dirname(__file__))

import overlay

class TestOverlay(unittest.TestCase):
    def setUp(self):
        # Reset global state for each test to ensure test isolation
        overlay.last_mtime = None
        overlay.cached_text = "keine Datei"

    @patch('os.path.getmtime', return_value=12345.6)
    @patch('builtins.open', new_callable=mock_open, read_data='1.0.0\n')
    def test_read_text_success(self, mock_file, mock_getmtime):
        """Test read_text when the file exists and contains text."""
        result = overlay.read_text()
        self.assertEqual(result, '1.0.0')
        mock_file.assert_called_once_with(overlay.TEXT_FILE)
        mock_getmtime.assert_called_once_with(overlay.TEXT_FILE)

    @patch('os.path.getmtime', side_effect=FileNotFoundError)
    @patch('builtins.open')
    def test_read_text_file_not_found(self, mock_file, mock_getmtime):
        """Test read_text when the file does not exist."""
        result = overlay.read_text()
        self.assertEqual(result, 'keine Datei')
        mock_file.assert_not_called()
        mock_getmtime.assert_called_once_with(overlay.TEXT_FILE)

    @patch('os.path.getmtime', return_value=12345.6)
    @patch('builtins.open', side_effect=Exception("Read error"))
    def test_read_text_open_fails(self, mock_file, mock_getmtime):
        """Test read_text when os.path.getmtime succeeds but open raises an exception."""
        result = overlay.read_text()
        self.assertEqual(result, 'keine Datei')
        mock_file.assert_called_once_with(overlay.TEXT_FILE)
        mock_getmtime.assert_called_once_with(overlay.TEXT_FILE)

    @patch('os.path.getmtime', return_value=12345.6)
    @patch('builtins.open')
    def test_read_text_cached(self, mock_file, mock_getmtime):
        """Test read_text when the file is unchanged, verifying it returns the cached text."""
        overlay.last_mtime = 12345.6
        overlay.cached_text = "cached value"

        result = overlay.read_text()
        self.assertEqual(result, 'cached value')
        mock_file.assert_not_called()
        mock_getmtime.assert_called_once_with(overlay.TEXT_FILE)

if __name__ == '__main__':
    unittest.main()
