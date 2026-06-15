import unittest
from unittest.mock import mock_open, patch, MagicMock
import os

from Windows.overlay import read_text
import Windows.overlay as overlay

class TestOverlay(unittest.TestCase):
    @patch("builtins.open", new_callable=mock_open, read_data="v1.2.3\n")
    def test_read_text_success(self, mock_file):
        result = read_text()
        self.assertEqual(result, "v1.2.3")
        mock_file.assert_called_once_with("/scripts/version.txt")

    @patch("builtins.open", side_effect=FileNotFoundError)
    def test_read_text_exception(self, mock_file):
        result = read_text()
        self.assertEqual(result, "keine Datei")
        mock_file.assert_called_once_with("/scripts/version.txt")

    @patch("Windows.overlay.read_text", return_value="v1.2.3")
    def test_update(self, mock_read_text):
        overlay.label = MagicMock()
        overlay.root = MagicMock()
        overlay.update()
        overlay.label.config.assert_called_once_with(text="v1.2.3")
        overlay.root.after.assert_called_once_with(overlay.REFRESH_MS, overlay.update)

if __name__ == "__main__":
    unittest.main()
