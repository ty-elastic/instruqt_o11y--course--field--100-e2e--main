import logging
from logging.handlers import SysLogHandler
from log_emitter import LogEmitter

DEBUG = False

class LogSyslog(LogEmitter):

    def __init__(self, *, service_name, max_logs_per_second, regional_attributes, language, mode=None):
        super().__init__(service_name=service_name, max_logs_per_second=max_logs_per_second, regional_attributes=regional_attributes, language=language, mode=mode)
        if not DEBUG:
            self.handler = SysLogHandler(address=('192.168.5.58', 9514))
            self.handler.append_nul = False
        else:
            self.handler = logging.StreamHandler()
        self.logger = logging.getLogger(service_name)
        self.logger.addHandler(self.handler)
        self.logger.setLevel(logging.INFO)

    def log(self, timestamp, level, body, node=None, component=None):
        if node is not None and component is not None:
            body = f'{node} {component} - - - {body}'
        super().log(timestamp, level, body)
