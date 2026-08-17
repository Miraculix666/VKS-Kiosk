🎯 **What:**
The `except Exception:` clause in `Windows/overlay.py`, `Linux/overlay.py`, and `Raspi/overlay.py` has been updated to `except FileNotFoundError:`.

💡 **Why:**
Catching generic exceptions can mask unexpected errors (such as permission issues or memory errors) and make debugging difficult. Catching only the expected `FileNotFoundError` explicitly improves maintainability and ensures that other potential errors are surfaced correctly.

✅ **Verification:**
Verified by running the test suites for Windows, Linux, and Raspi, modifying the corresponding test files to mock `FileNotFoundError` instead of generic `Exception` or `IOError` to match the exact exception handled.

✨ **Result:**
The codebase now follows better error handling practices by using precise exception matching in the file read functions, ensuring unexpected errors are appropriately raised without breaking the current flow for a missing version file.
