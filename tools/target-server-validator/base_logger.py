#!/usr/bin/python

# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


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
    logging_format = "%(asctime)s - %(name)s - %(levelname)s - %(message)s (%(filename)s:%(lineno)d)"  # noqa

    FORMATS = {
        logging.DEBUG: grey + logging_format + reset,
        logging.INFO: grey + logging_format + reset,
        logging.WARNING: yellow + logging_format + reset,
        logging.ERROR: red + logging_format + reset,
        logging.CRITICAL: bold_red + logging_format + reset
    }

    def format(self, record):
        log_fmt = self.FORMATS.get(record.levelno)
        formatter = logging.Formatter(log_fmt)
        return formatter.format(record)


logger = logging.getLogger("TargetServerValidator")
logger.setLevel(getattr(logging, LOGLEVEL))

if LOG_HANDLER == "File":
    ch = logging.FileHandler(LOG_FILE_PATH, mode="a")
else:
    ch = logging.StreamHandler()

ch.setFormatter(CustomFormatter())

logger.addHandler(ch)
