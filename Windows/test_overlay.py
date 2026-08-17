import unittest
from unittest.mock import patch, mock_open, MagicMock
import sys
import os

sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

with patch('tkinter.Tk'):
    import overlay

class TestOverlay(unittest.TestCase):
    def setUp(self):
        overlay.last_mtime = None
        overlay.cached_text = "keine Datei"

    @patch('os.path.getmtime')
    @patch('builtins.open', new_callable=mock_open, read_data="v1.0")
    def test_read_text_success_first_read(self, mock_file, mock_getmtime):
        mock_getmtime.return_value = 12345.0
        result = overlay.read_text()
        self.assertEqual(result, "v1.0")
        mock_getmtime.assert_called_once_with(overlay.TEXT_FILE)
        mock_file.assert_called_once_with(overlay.TEXT_FILE)

    @patch('os.path.getmtime')
    @patch('builtins.open', new_callable=mock_open, read_data="v1.0")
    def test_read_text_cached(self, mock_file, mock_getmtime):
        # Set up cache state
        overlay.last_mtime = 12345.0
        overlay.cached_text = "v1.0"
        mock_getmtime.return_value = 12345.0

        result = overlay.read_text()

        self.assertEqual(result, "v1.0")
        mock_getmtime.assert_called_once_with(overlay.TEXT_FILE)
        mock_file.assert_not_called()

    @patch('os.path.getmtime')
    @patch('builtins.open', side_effect=IOError)
    def test_read_text_error(self, mock_file, mock_getmtime):
        mock_getmtime.return_value = 12345.0
        result = overlay.read_text()
        self.assertEqual(result, "keine Datei")
        mock_getmtime.assert_called_once_with(overlay.TEXT_FILE)
        mock_file.assert_called_once_with(overlay.TEXT_FILE)

    @patch('os.path.getmtime', side_effect=FileNotFoundError)
    @patch('builtins.open', new_callable=mock_open)
    def test_read_text_mtime_error(self, mock_file, mock_getmtime):
        result = overlay.read_text()
        self.assertEqual(result, "keine Datei")
        mock_getmtime.assert_called_once_with(overlay.TEXT_FILE)
        mock_file.assert_not_called()

if __name__ == '__main__':
    unittest.main()
