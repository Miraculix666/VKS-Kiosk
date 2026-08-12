import unittest
from unittest.mock import patch, mock_open
import sys
import os

sys.path.insert(0, os.path.dirname(__file__))

with patch('tkinter.Tk'):
    import overlay

class TestOverlay(unittest.TestCase):
    def setUp(self):
        overlay.last_mtime = None
        overlay.cached_text = "keine Datei"

    @patch('os.path.getmtime', return_value=12345.0)
    @patch('builtins.open', new_callable=mock_open, read_data='1.0.0\n')
    def test_read_text_success(self, mock_file, mock_getmtime):
        """Test read_text when the file exists and contains text."""
        mock_getmtime.return_value = 12345.0
        result = overlay.read_text()
        self.assertEqual(result, '1.0.0')
        mock_file.assert_called_once_with(overlay.TEXT_FILE)
        mock_getmtime.assert_called_once_with(overlay.TEXT_FILE)

    @patch('os.path.getmtime', side_effect=FileNotFoundError)
    @patch('builtins.open', new_callable=mock_open)
    def test_read_text_file_not_found(self, mock_file, mock_getmtime):
        """Test read_text when the file does not exist."""
        mock_getmtime.return_value = 12345.0
        result = overlay.read_text()
        self.assertEqual(result, 'keine Datei')
        mock_file.assert_not_called()
        mock_getmtime.assert_called_once_with(overlay.TEXT_FILE)

if __name__ == '__main__':
    unittest.main()
