import unittest
from unittest.mock import patch, mock_open, MagicMock
import sys
import os

sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))
import overlay

class TestOverlay(unittest.TestCase):
    @patch('builtins.open', new_callable=mock_open, read_data="v1.0")
    def test_read_text_success(self, mock_file):
        result = overlay.read_text()
        self.assertEqual(result, "v1.0")
        mock_file.assert_called_once_with(overlay.TEXT_FILE)

    @patch('builtins.open', side_effect=IOError)
    def test_read_text_error(self, mock_file):
        result = overlay.read_text()
        self.assertEqual(result, "keine Datei")
        mock_file.assert_called_once_with(overlay.TEXT_FILE)

    @patch('overlay.read_text', return_value="v1.0")
    def test_update(self, mock_read_text):
        # We need to create these before mocking because they only exist in __main__ execution
        with patch.object(overlay, 'root', create=True, new_callable=MagicMock) as mock_root, \
             patch.object(overlay, 'label', create=True, new_callable=MagicMock) as mock_label:
            overlay.update()
            mock_label.config.assert_called_once_with(text="v1.0")
            mock_root.after.assert_called_once_with(overlay.REFRESH_MS, overlay.update)

if __name__ == '__main__':
    unittest.main()
