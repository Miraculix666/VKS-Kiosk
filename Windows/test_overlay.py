import unittest
from unittest.mock import patch, mock_open

import overlay

class TestOverlay(unittest.TestCase):
    @patch('builtins.open', new_callable=mock_open, read_data="v1.0.0\n")
    def test_read_text_success(self, mock_file):
        result = overlay.read_text()
        self.assertEqual(result, "v1.0.0")

    @patch('builtins.open', side_effect=OSError("Test Exception"))
    def test_read_text_exception(self, mock_file):
        result = overlay.read_text()
        self.assertEqual(result, "keine Datei")

if __name__ == '__main__':
    unittest.main()
