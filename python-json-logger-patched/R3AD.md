# python-json-logger-patched

A security-hardened, actively-maintained fork of [python-json-logger](https://github.com/madzak/python-json-logger).

## 🚀 Why This Fork?

- The original project is no longer maintained.
- Log injection and control character abuse are real threats.
- This fork provides modern Python compatibility, input sanitization, and regular dependency upgrades.

## 🔒 Security Improvements

- **Input Sanitization:** Strips control characters and encodes dangerous sequences in all log fields.
- **Defense-in-Depth:** Handles nested structures (dicts/lists), not just strings.
- **Security Tests:** Includes tests for log injection, malicious payloads, and malformed data.
- **Modern Python Support:** Fully tested on Python 3.7+.

## 🛠️ Usage

```python
import logging
from pythonjsonlogger_patched import JsonFormatter

logger = logging.getLogger()
logHandler = logging.StreamHandler()
formatter = JsonFormatter()
logHandler.setFormatter(formatter)
logger.addHandler(logHandler)

logger.info("User login attempt", extra={"user": "test@evil.com\n<script>alert(1)</script>"})