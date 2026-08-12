import unittest
from unittest.mock import mock_open, patch
import Raspi.overlay as overlay

class TestOverlay(unittest.TestCase):

    @patch('builtins.open', new_callable=mock_open, read_data="v1.0.0")
    def test_read_text_success(self, mock_file):
        """Test read_text when the file exists and can be read successfully."""
        result = overlay.read_text()
        self.assertEqual(result, "v1.0.0")
        mock_file.assert_called_once_with(overlay.TEXT_FILE)

    @patch('builtins.open')
    def test_read_text_error(self, mock_file):
        """Test read_text when an IOError occurs (e.g., file not found)."""
        mock_file.side_effect = IOError("File not found")
        result = overlay.read_text()
        self.assertEqual(result, "keine Datei")
        mock_file.assert_called_once_with(overlay.TEXT_FILE)

if __name__ == '__main__':
    unittest.main()
