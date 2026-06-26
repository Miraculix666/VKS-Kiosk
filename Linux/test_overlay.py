import unittest
from unittest.mock import mock_open, patch, MagicMock
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

# Prevent module level execution of UI code by mocking tkinter
with patch('tkinter.Tk'):
    with patch('tkinter.Frame'):
        with patch('tkinter.Label'):
            import overlay

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

if __name__ == "__main__":
    unittest.main()
