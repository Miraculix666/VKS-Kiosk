import unittest
from unittest.mock import mock_open, patch
import os

from Linux.overlay import read_text

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

if __name__ == "__main__":
    unittest.main()
