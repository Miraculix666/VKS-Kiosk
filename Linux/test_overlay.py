import unittest
from unittest.mock import mock_open, patch
import os

import Linux.overlay as overlay
from unittest.mock import MagicMock

class TestOverlay(unittest.TestCase):
    @patch("builtins.open", new_callable=mock_open, read_data="v1.2.3\n")
    def test_read_text_success(self, mock_file):
        result = overlay.read_text()
        self.assertEqual(result, "v1.2.3")
        mock_file.assert_called_once_with("/scripts/version.txt")

    @patch("builtins.open", side_effect=FileNotFoundError)
    def test_read_text_exception(self, mock_file):
        result = overlay.read_text()
        self.assertEqual(result, "keine Datei")
        mock_file.assert_called_once_with("/scripts/version.txt")

    @patch("Linux.overlay.read_text", return_value="v2.0.0")
    def test_update(self, mock_read_text):
        overlay.label = MagicMock()
        overlay.root = MagicMock()

        overlay.update()

        overlay.label.config.assert_called_once_with(text="v2.0.0")
        overlay.root.after.assert_called_once_with(overlay.REFRESH_MS, overlay.update)

if __name__ == "__main__":
    unittest.main()
