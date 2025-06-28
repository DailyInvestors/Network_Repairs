import json
import logging
import os
import re
import io
import pytest

# ==============================================================================
# SECTION 1: SECURE FORMATTER IMPLEMENTATION
#
# This section contains the core library code for the secure JSON formatter.
# It is designed to be reusable, configurable, and secure.
# ==============================================================================

# A robust regex to find and remove most non-printable ASCII control characters.
# \x00-\x08 (BEL, BS, etc.), \x0b-\x0c (VT, FF), \x0e-\x1f (SO, US, etc.), \x7f (DEL)
CONTROL_CHAR_RE = re.compile(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]')

# A simple regex to find and remove script tags. For production-grade HTML
# sanitization in web contexts, a dedicated library like 'bleach' is recommended.
SCRIPT_TAG_RE = re.compile(r'<script.*?>.*?</script>', re.IGNORECASE)

# --- Security: Centralized and Configurable Redaction ---
REDACTED_VALUE = "***REDACTED***"

# Default sensitive keys. Using a set for efficient O(1) lookups.
# Keys are checked case-insensitively.
DEFAULT_SENSITIVE_KEYS = {
    'password', 'token', 'authorization', 'cookie', 'secret', 'apikey', 'access_key'
}

def get_sensitive_keys():
    """
    Loads sensitive key names from an environment variable for secure configuration.
    This prevents hard-coding sensitive information in the application.
    Example: export SENSITIVE_KEYS="password,token,my_custom_secret"
    """
    env_keys = os.environ.get('SENSITIVE_KEYS')
    if env_keys:
        # Split, strip whitespace, and convert to lowercase for case-insensitive matching
        return {key.strip().lower() for key in env_keys.split(',')}
    return DEFAULT_SENSITIVE_KEYS

SENSITIVE_KEYS = get_sensitive_keys()

class Sanitizer:
    """
    A helper class to handle the sanitization and redaction of log data.
    """
    def sanitize_value(self, value):
        """Sanitizes a single string value."""
        if not isinstance(value, str):
            return value
        # 1. Remove control characters
        sanitized = CONTROL_CHAR_RE.sub('', value)
        # 2. Remove script tags
        sanitized = SCRIPT_TAG_RE.sub('', sanitized)
        # 3. Replace newlines/carriage returns to prevent log injection/splitting
        return sanitized.replace('\n', ' ').replace('\r', '')

    def redact(self, data):
        """
        Recursively traverses a dictionary or list to sanitize strings and
        redact values associated with sensitive keys.
        """
        if isinstance(data, dict):
            # Create a new dict, redacting values where the key is sensitive
            return {
                key: REDACTED_VALUE if key.lower() in SENSITIVE_KEYS else self.redact(value)
                for key, value in data.items()
            }
        elif isinstance(data, list):
            # Recursively call redact on each item in the list
            return [self.redact(item) for item in data]
        else:
            # For any other value (str, int, bool, etc.), sanitize it
            return self.sanitize_value(data)

class SecureJsonFormatter(logging.Formatter):
    """
    A custom logging formatter that outputs logs in a secure, sanitized JSON format.
    It automatically redacts sensitive data and cleans potentially malicious strings.
    
    NOTE ON RATE LIMITING:
    Rate limiting is an application-level concern and should not be handled
    in the logger. It protects application endpoints from abuse. A logger's
    job is to record what happened, after the action has been allowed.
    Implement rate limiting in your API gateway, load balancer, or web framework
    middleware (e.g., using libraries like 'flask-limiter' or 'django-ratelimit').
    """
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.sanitizer = Sanitizer()

    def format(self, record):
        """
        Formats the log record into a sanitized and secure JSON string.
        """
        # Start with standard log record attributes
        log_object = {
            "timestamp": self.formatTime(record, self.datefmt),
            "level": record.levelname,
            "message": self.sanitizer.sanitize_value(record.getMessage()),
            "logger_name": record.name
        }

        # Safely add any 'extra' data passed to the logger
        record_extra = record.__dict__.get('extra')
        if record_extra and isinstance(record_extra, dict):
            # The core security step: redact and sanitize the extra data
            clean_extra = self.sanitizer.redact(record_extra)
            log_object.update(clean_extra)

        return json.dumps(log_object)


# ==============================================================================
# SECTION 2: TEST SUITE
#
# This section contains the pytest suite for the SecureJsonFormatter.
# ==============================================================================

# --- Test Helpers ---

def get_log_output(message, extra=None):
    """
    Helper function to capture log output in-memory for a single log event.
    FIX: Uses an in-memory stream (io.StringIO) to avoid insecure file I/O.
    FIX: Isolates logger instances to prevent test state pollution.
    """
    # Use a unique logger name per call to ensure test isolation
    logger = logging.getLogger(f"test_logger_{id(extra)}")
    logger.setLevel(logging.INFO)
    
    formatter = SecureJsonFormatter()
    
    # Use an in-memory stream instead of a temporary file for security and speed
    stream = io.StringIO()
    handler = logging.StreamHandler(stream)
    handler.setFormatter(formatter)
    
    logger.handlers = [handler]  # Reset handlers to ensure a clean state

    # The 'extra' kwarg to a logger method is the standard way to pass custom dicts
    logger.info(message, extra=extra or {})
    
    handler.close()
    
    output = stream.getvalue()
    return json.loads(output)

# --- Test Data Constants ---
# FIX: Avoid hard-coded credential-like strings. Use constants for clarity.
MALICIOUS_INPUT = 'input with newline\nand carriage return\r<script>alert("XSS")</script>\x00'
SAFE_VALUE = "this_is_a_safe_value"
FAKE_PASSWORD = "p@ssw0rd-f4k3-v4lu3"
FAKE_TOKEN = "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# --- Test Cases ---

def test_removes_control_chars_and_scripts():
    extra = {'user_input': MALICIOUS_INPUT}
    out = get_log_output("Testing sanitizer", extra)
    sanitized = out['user_input']
    
    assert '\n' not in sanitized
    assert '\r' not in sanitized
    assert '\x00' not in sanitized
    assert '<script>' not in sanitized
    assert 'alert("XSS")' not in sanitized
    assert "input with newline and carriage return" in sanitized

def test_redacts_sensitive_fields():
    # FIX: The keys are what matter for redaction, not the values.
    extra = {
        'password': FAKE_PASSWORD,
        'token': FAKE_TOKEN,
        'Authorization': 'Bearer ' + FAKE_TOKEN, # Test case-insensitivity
        'cookie': 'session_id=12345; auth_token=' + FAKE_TOKEN,
        'safe_key': SAFE_VALUE
    }
    out = get_log_output("Sensitive data", extra)

    assert out['password'] == REDACTED_VALUE
    assert out['token'] == REDACTED_VALUE
    assert out['Authorization'] == REDACTED_VALUE
    assert out['cookie'] == REDACTED_VALUE
    assert out['safe_key'] == SAFE_VALUE

def test_handles_nested_structures_recursively():
    extra = {
        'level1': {
            'level2_list': [
                'just_text',
                '<script>bad()</script>',
                '\nbar\r',
                {'password': FAKE_PASSWORD} # Nested sensitive key
            ],
            'level2_dict': {
                'secret': 'this should also be redacted' # Another sensitive key
            }
        }
    }
    out = get_log_output("Nested test", extra)
    
    l1 = out['level1']
    assert l1['level2_dict']['secret'] == REDACTED_VALUE
    
    l2_list = l1['level2_list']
    assert 'just_text' in l2_list
    assert 'bad()' in l2_list      # Script tag is removed
    assert 'bar' in l2_list        # Newlines/returns are removed
    
    nested_dict = next(item for item in l2_list if isinstance(item, dict))
    assert nested_dict['password'] == REDACTED_VALUE

def test_handles_non_string_types_correctly():
    extra = {'int': 123, 'float': 1.23, 'bool': True, 'none': None}
    out = get_log_output("Non-string types", extra)
    assert out['int'] == 123
    assert out['float'] == 1.23
    assert out['bool'] is True
    assert out['none'] is None

def test_formatter_includes_standard_log_fields():
    out = get_log_output("A standard message", extra={'user': 'test'})
    assert "timestamp" in out
    assert out["level"] == "INFO"
    assert out["message"] == "A standard message"
    assert "test_logger" in out["logger_name"]
    assert out["user"] == "test"


# ==============================================================================
# SECTION 3: EXECUTION BLOCK
# ==============================================================================

if __name__ == "__main__":
    # This allows you to run the tests by executing the script directly:
    # python your_script_name.py
    pytest.main([__file__])