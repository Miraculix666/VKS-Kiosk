import unittest
from unittest.mock import mock_open, patch, MagicMock
import os
import sys

from Windows.overlay import read_text
import Windows.overlay as overlay

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

    @patch("Windows.overlay.read_text", return_value="v1.2.3")
    def test_update(self, mock_read_text):
        overlay.label = MagicMock()
        overlay.root = MagicMock()
        overlay.update()
        overlay.label.config.assert_called_once_with(text="v1.2.3")
        overlay.root.after.assert_called_once_with(overlay.REFRESH_MS, overlay.update)

if __name__ == "__main__":
    unittest.main()
