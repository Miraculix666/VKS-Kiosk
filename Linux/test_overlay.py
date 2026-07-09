import unittest
from unittest.mock import patch, mock_open, MagicMock
import os
import tkinter as tk

# Important: ensure we can import overlay from Linux
import Linux.overlay as overlay

class TestOverlay(unittest.TestCase):
    def test_read_text_success(self):
        with patch('builtins.open', mock_open(read_data='1.0.0')):
            result = overlay.read_text()
            self.assertEqual(result, '1.0.0')

    def test_read_text_failure(self):
        with patch('builtins.open', side_effect=Exception('File not found')):
            result = overlay.read_text()
            self.assertEqual(result, 'keine Datei')

    @patch('Linux.overlay.read_text', return_value='1.2.3')
    def test_update(self, mock_read_text):
        mock_root = MagicMock()
        mock_label = MagicMock()

        overlay.update(mock_root, mock_label)

        mock_label.config.assert_called_once_with(text='1.2.3')
        mock_root.after.assert_called_once_with(overlay.REFRESH_MS, overlay.update, mock_root, mock_label)

    @patch('Linux.overlay.tk.Tk')
    @patch('Linux.overlay.tk.Frame')
    @patch('Linux.overlay.tk.Label')
    @patch('Linux.overlay.update')
    @patch.dict(os.environ, {}, clear=True)
    def test_main(self, mock_update, mock_label_class, mock_frame_class, mock_tk_class):
        mock_root = MagicMock()
        mock_tk_class.return_value = mock_root
        mock_root.winfo_screenwidth.return_value = 1920

        mock_label = MagicMock()
        mock_label_class.return_value = mock_label

        overlay.main()

        # Verify display environment variable logic
        self.assertEqual(os.environ.get('DISPLAY'), ':0.0')

        # Verify Tk initialization and config
        mock_tk_class.assert_called_once()
        mock_root.overrideredirect.assert_called_with(True)
        mock_root.attributes.assert_any_call("-topmost", True)
        mock_root.attributes.assert_any_call("-alpha", 0.0)

        # Verify geometry
        mock_root.winfo_screenwidth.assert_called_once()
        mock_root.geometry.assert_called_with("+1825+0")

        # Verify update call
        mock_update.assert_called_once_with(mock_root, mock_label)

        # Verify mainloop
        mock_root.mainloop.assert_called_once()

if __name__ == '__main__':
    unittest.main()
