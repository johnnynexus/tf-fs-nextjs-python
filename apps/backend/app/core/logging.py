"""Logging setup.

Cloud Run (and most container platforms) collect stdout/stderr, so logging to
the console is all that is needed. JSON output is used outside local dev so
Cloud Logging parses severity and message fields instead of treating every
line as plain text.
"""

import json
import logging
import sys
from typing import Any

from app.core.config import Settings


class CloudLoggingFormatter(logging.Formatter):
    """Minimal structured formatter understood by Google Cloud Logging."""

    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            # Cloud Logging picks up "severity" and "message" automatically.
            "severity": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
        }
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        return json.dumps(payload)


def configure_logging(settings: Settings) -> None:
    handler = logging.StreamHandler(sys.stdout)

    if settings.environment == "local":
        handler.setFormatter(
            logging.Formatter("%(asctime)s %(levelname)-8s %(name)s | %(message)s")
        )
    else:
        handler.setFormatter(CloudLoggingFormatter())

    root = logging.getLogger()
    # Replace any handler installed by a previous call so repeated setup in
    # tests does not duplicate every log line.
    root.handlers = [handler]
    root.setLevel(settings.log_level.upper())

    # uvicorn installs its own handlers; defer them to the root logger so all
    # output shares one format.
    for name in ("uvicorn", "uvicorn.error", "uvicorn.access"):
        uvicorn_logger = logging.getLogger(name)
        uvicorn_logger.handlers = []
        uvicorn_logger.propagate = True
