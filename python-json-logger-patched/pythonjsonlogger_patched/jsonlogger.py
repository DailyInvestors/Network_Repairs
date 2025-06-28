
import logging
import json
from datetime import datetime
import re

class JsonFormatter(logging.Formatter):
    CONTROL_CHARS = re.compile(r'[\x00-\x1f\x7f-\x9f]')
    DANGEROUS_KEYS = {'password', 'secret', 'token', 'authorization', 'cookie'}

    def add_fields(self, log_record, record, message_dict):
        for key, value in message_dict.items():
            sanitized_key = self._sanitize(key)
            if sanitized_key.lower() in self.DANGEROUS_KEYS:
                log_record[sanitized_key] = "***REDACTED***"
            else:
                log_record[sanitized_key] = self._sanitize(value)
        if not log_record.get('timestamp'):
            log_record['timestamp'] = datetime.utcnow().isoformat() + 'Z'
        if not log_record.get('level'):
            log_record['level'] = record.levelname
        if not log_record.get('name'):
            log_record['name'] = record.name
        if not log_record.get('message'):
            log_record['message'] = record.getMessage()

    def _sanitize(self, value):
        if isinstance(value, str):
            # Remove control characters, escape dangerous characters
            value = self.CONTROL_CHARS.sub('', value)
            value = (
                value.replace('\\', '\\\\')
                     .replace('"', '\\"')
                     .replace('\n', '\\n')
                     .replace('\r', '\\r')
            )
            # Remove simple script tags
            value = re.sub(r'<\s*script.*?>.*?<\s*/\s*script\s*>', '', value, flags=re.IGNORECASE|re.DOTALL)
            return value
        elif isinstance(value, dict):
            return {self._sanitize(k): self._sanitize(v) for k, v in value.items()}
        elif isinstance(value, list):
            return [self._sanitize(v) for v in value]
        elif isinstance(value, (int, float, bool)) or value is None:
            return value
        else:
            # Fallback: convert unknown types to string, then sanitize
            return self._sanitize(str(value))

    def format(self, record):
        log_record = {}
        # Merge extra fields, if present
        message_dict = getattr(record, 'extra', {})
        self.add_fields(log_record, record, message_dict)
        return json.dumps(log_record, ensure_ascii=False)


