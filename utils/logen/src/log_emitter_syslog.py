import logging
from logging.handlers import SysLogHandler
from log_emitter import LogEmitter
from rfc5424logging import Rfc5424SysLogHandler, Rfc5424SysLogAdapter

DEBUG = False

class LogSyslog(LogEmitter):

    def __init__(self, *, service_name, max_logs_per_second, regional_attributes, language, mode=None):
        super().__init__(service_name=service_name, max_logs_per_second=max_logs_per_second, regional_attributes=regional_attributes, language=language, mode=mode)

        if not DEBUG:
            self.handler = Rfc5424SysLogHandler(address=('127.0.0.1', 9514))
        else:
            self.handler = logging.StreamHandler()

        self.logger = logging.getLogger(service_name)
        self.logger.addHandler(self.handler)
        self.logger.setLevel(logging.INFO)
