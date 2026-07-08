#!/usr/bin/env python3
"""
WebSocket event listener for VideoDB with auto-reconnect and graceful shutdown.

Usage:
  python scripts/ws_listener.py [OPTIONS] [output_dir]

Arguments:
  output_dir  Directory for output files (default: XDG_STATE_HOME/videodb or ~/.local/state/videodb)

Options:
  --clear     Clear the events file before starting (use when starting a new session)

Output files:
  <output_dir>/videodb_events.jsonl  - All WebSocket events (JSONL format)
  <output_dir>/videodb_ws_id         - WebSocket connection ID
  <output_dir>/videodb_ws_pid        - Process ID for easy termination

Output (first line, for parsing):
  WS_ID=<connection_id>

Examples:
  python scripts/ws_listener.py &                                 # Run in background
  python scripts/ws_listener.py --clear                           # Clear events and start fresh
  python scripts/ws_listener.py --clear /tmp/mydir                # Custom dir with clear
  kill "$(cat ~/.local/state/videodb/videodb_ws_pid)"             # Stop the listener
"""
import os
import sys
import json
import signal
import asyncio
import logging
import contextlib
from datetime import datetime, timezone
from pathlib import Path

from dotenv import load_dotenv
load_dotenv()

import videodb
from videodb.exceptions import AuthenticationError

# Retry config
MAX_RETRIES = 10
INITIAL_BACKOFF = 1  # seconds
MAX_BACKOFF = 60     # seconds

logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] %(message)s",
    datefmt="%H:%M:%S",
)
LOGGER = logging.getLogger(__name__)

# Parse arguments
RETRYABLE_ERRORS = (ConnectionError, TimeoutError)


def default_output_dir() -> Path:
    """Return a private per-user state directory for listener artifacts."""
    xdg_state_home = os.environ.get("XDG_STATE_HOME")
    if xdg_state_home:
        return Path(xdg_state_home) / "videodb"
    return Path.home() / ".local" / "state" / "videodb"


def ensure_private_dir(path: Path) -> Path:
    """Create the listener state directory with private permissions."""
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    try:
        path.chmod(0o700)
    except OSError:
        pass
    return path


def parse_args() -> tuple[bool, Path]:
    clear = False
    output_dir: str | None = None
    
    args = sys.argv[1:]
    for arg in args:
        if arg == "--clear":
            clear = True
        elif arg.startswith("-"):
            raise SystemExit(f"Unknown flag: {arg}")
        elif not arg.startswith("-"):
            output_dir = arg
    
    if output_dir is None:
        events_dir = os.environ.get("VIDEODB_EVENTS_DIR")
        if events_dir:
            return clear, ensure_private_dir(Path(events_dir))
        return clear, ensure_private_dir(default_output_dir())

    return clear, ensure_private_dir(Path(output_dir))

CLEAR_EVENTS, OUTPUT_DIR = parse_args()
EVENTS_FILE = OUTPUT_DIR / "videodb_events.jsonl"
WS_ID_FILE = OUTPUT_DIR / "videodb_ws_id"
PID_FILE = OUTPUT_DIR / "videodb_ws_pid"

# Track if this is the first connection (for clearing events)
_first_connection = True


def log(msg: str):
    """Log with timestamp."""
    LOGGER.info("%s", msg)


def append_event(event: dict):
    """Append event to JSONL file with timestamps."""
    now = datetime.now(timezone.utc)
    event["ts"] = now.isoformat()
    event["unix_ts"] = now.timestamp()
    with EVENTS_FILE.open("a", encoding="utf-8") as f:
        f.write(json.dumps(event) + "\n")


def write_pid():
    """Write PID file for easy process management."""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
    PID_FILE.write_text(str(os.getpid()))


def cleanup_pid():
    """Remove PID file on exit."""
    try:
        PID_FILE.unlink(missing_ok=True)
    except OSError as exc:
        LOGGER.debug("Failed to remove PID file %s: %s", PID_FILE, exc)


def is_fatal_error(exc: Exception) -> bool:
    """Return True when retrying would hide a permanent configuration error.""