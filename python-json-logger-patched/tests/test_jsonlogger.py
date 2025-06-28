import logging
import json
import pytest
from pythonjsonlogger_patched import JsonFormatter

def get_log_output(message, extra=None):
    logger = logging.getLogger("test_logger")
    logger.setLevel(logging.INFO)
    stream = logging.StreamHandler()
    formatter = JsonFormatter()
    stream.setFormatter(formatter)
    logger.handlers = [stream]  # Reset handlers
    with open('test_log_output.json', 'w', encoding='utf-8') as f:
        for handler in logger.handlers:
            handler.stream = f  # Redirect handler to file
        logger.info(message, extra={'extra': extra or {}})
    with open('test_log_output.json', 'r', encoding='utf-8') as f:
        output = f.read()
    return json.loads(output)

def test_removes_control_and_script():
    malicious = 'hello\nworld\r<script>alert("x")</script>\x00'
    extra = {'user_input': malicious}
    out = get_log_output("Testing sanitizer", extra)
    sanitized = out['user_input']
    assert '\n' not in sanitized
    assert '\r' not in sanitized
    assert '\x00' not in sanitized
    assert '<script>' not in sanitized and 'alert("x")' not in sanitized

def test_redacts_sensitive_fields():
    extra = {
        'password': 'supersecret',
        'token': 'abc123',
        'Authorization': 'Bearer 123',
        'cookie': 'testcookie',
        'safe_key': 'ok'
    }
    out = get_log_output("Sensitive data", extra)
    assert out['password'] == out['token'] == out['authorization'] == out['cookie'] == "***REDACTED***"
    assert out['safe_key'] == "ok"

def test_handles_nested_structures():
    extra = {
        'level1': {
            'level2': ['foo', '<script>bad()</script>', '\nbar\r']
        }
    }
    out = get_log_output("Nested test", extra)
    l2 = out['level1']['level2']
    assert all('<script>' not in item and '\n' not in item and '\r' not in item for item in l2)

def test_handles_non_string_types():
    extra = {'int': 123, 'float': 1.23, 'bool': True, 'none': None}
    out = get_log_output("Non-string types", extra)
    assert out['int'] == 123
    assert out['float'] == 1.23
    assert out['bool'] is True
    assert out['none'] is None

if __name__ == "__main__":
    pytest.main([__file__])