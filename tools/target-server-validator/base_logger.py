import os
import logging

EXEC_INFO = True if os.getenv("EXEC_INFO") == "True" else False
LOG_HANDLER = os.getenv("LOG_HANDLER", "Stream")
LOG_FILE_PATH = os.getenv("LOG_FILE_PATH", "app.log")
LOGLEVEL = os.getenv('LOGLEVEL', 'INFO').upper()

if LOG_HANDLER not in {"File", "Stream"}:
    LOG_HANDLER = "Stream"

if LOGLEVEL not in {"CRITICAL", "ERROR", "WARNING", "INFO", "DEBUG", "NOTSET"}:
    LOGLEVEL = "INFO"


class CustomFormatter(logging.Formatter):

    grey = "\x1b[38;20m"
    yellow = "\x1b[33;20m"
    red = "\x1b[31;20m"
    bold_red = "\x1b[31;1m"
    reset = "\x1b[0m"
    format = "%(asctime)s - %(name)s - %(levelname)s - %(message)s (%(filename)s:%(lineno)d)"  # noqa

    FORMATS = {
        logging.DEBUG: grey + format + reset,
        logging.INFO: grey + format + reset,
        logging.WARNING: yellow + format + reset,
        logging.ERROR: red + format + reset,
        logging.CRITICAL: bold_red + format + reset
    }

    def format(self, record):
        log_fmt = self.FORMATS.get(record.levelno)
        formatter = logging.Formatter(log_fmt)
        return formatter.format(record)


logger = logging.getLogger("TargetServerValidator")
logger.setLevel(getattr(logging, LOGLEVEL))  # Add this line

if LOG_HANDLER == "File":
    ch = logging.FileHandler(LOG_FILE_PATH, mode="a")
else:
    ch = logging.StreamHandler()

ch.setFormatter(CustomFormatter())

logger.addHandler(ch)
