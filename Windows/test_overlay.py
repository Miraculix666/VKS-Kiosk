import unittest
from unittest.mock import mock_open, patch
import Windows.overlay as overlay

class TestOverlay(unittest.TestCase):
    @patch('builtins.open', new_callable=mock_open, read_data='1.0.0\n')
    def test_read_text_success(self, mock_file):
        """Test read_text returns stripped content when file exists."""
        result = overlay.read_text()
        self.assertEqual(result, '1.0.0')
        mock_file.assert_called_once_with(overlay.TEXT_FILE)

    @patch('builtins.open')
    def test_read_text_exception(self, mock_file):
        """Test read_text returns 'keine Datei' when an exception occurs."""
        mock_file.side_effect = FileNotFoundError
        result = overlay.read_text()
        self.assertEqual(result, 'keine Datei')

if __name__ == '__main__':
    unittest.main()
