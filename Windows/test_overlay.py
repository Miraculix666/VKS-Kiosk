import unittest
from unittest.mock import patch, mock_open, MagicMock
import sys
import os

sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))
import overlay

class TestOverlay(unittest.TestCase):
    def setUp(self):
        overlay.last_mtime = None
        overlay.cached_text = "keine Datei"

    @patch('os.path.getmtime')
    def test_read_text_success(self, mock_getmtime):
        # Test scenario 1: file is read successfully and returns trimmed content.
        mock_getmtime.return_value = 12345.67
        mocked_file_content = "   Test Version 1.0.0   \n"
        with patch('builtins.open', mock_open(read_data=mocked_file_content)):
            result = overlay.read_text()
            self.assertEqual(result, "Test Version 1.0.0")

    @patch('os.path.getmtime')
    def test_read_text_exception(self, mock_getmtime):
        # Test scenario 2: an exception occurs (e.g. file not found) and returns "keine Datei".
        mock_getmtime.side_effect = Exception("File not found")
        result = overlay.read_text()
        self.assertEqual(result, "keine Datei")

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
