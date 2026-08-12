import unittest
from unittest.mock import mock_open, patch
import Raspi.overlay as overlay

class TestOverlay(unittest.TestCase):
    def setUp(self):
        overlay.last_mtime = None
        overlay.cached_text = "keine Datei"

    @patch('os.path.getmtime', return_value=12345.0)
    @patch('builtins.open', new_callable=mock_open, read_data='1.0.0\n')
    def test_read_text_success(self, mock_file, mock_getmtime):
        """Test read_text when the file exists and contains text."""
        result = overlay.read_text()
        self.assertEqual(result, "v1.0.0")
        mock_file.assert_called_once_with(overlay.TEXT_FILE)
        mock_getmtime.assert_called_once_with(overlay.TEXT_FILE)

    @patch('os.path.getmtime', side_effect=FileNotFoundError)
    @patch('builtins.open', side_effect=FileNotFoundError)
    def test_read_text_file_not_found(self, mock_file, mock_getmtime):
        """Test read_text when the file does not exist."""
        result = overlay.read_text()
        self.assertEqual(result, 'keine Datei')
        mock_file.assert_not_called()
        mock_getmtime.assert_called_once_with(overlay.TEXT_FILE)

if __name__ == '__main__':
    unittest.main()
