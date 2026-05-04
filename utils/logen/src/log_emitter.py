from abc import ABC, abstractmethod

LOG_LEVEL_LOOKUP = {
    'DEBUG': 10,
    'INFO': 20,
    'WARN': 30,
    'WARNING': 30,
    'ERROR': 40,
    'CRITICAL': 50,
    'FATAL': 50
}

class LogEmitter(ABC):

    def log_backoff(processor):
        pass

    def __init__(self, *, service_name, max_logs_per_second, regional_attributes, language, mode=None):
        self.service_name = service_name
        self.max_logs_per_second = max_logs_per_second
        self.regional_attributes = regional_attributes
        self.language = language
        self.mode = mode
        self.start_time = None

        self.logger = None
        self.processor = None
        self.handler = None

    def log(self, timestamp, level, body, node=None, component=None):
        level_num = LOG_LEVEL_LOOKUP[level]

        ct = timestamp.timestamp()
        if self.start_time is None:
            self.start_time = ct
        record = self.logger.makeRecord(self.service_name, level_num, f'{self.service_name}.py', 0, body, None, None)
        record.created = ct
        record.msecs = ct * 1000
        record.relativeCreated = (record.created - self.start_time) * 1000

        if node is not None:
            setattr(record, 'hostname', node)
        if component is not None:
            setattr(record, 'appname', f"{self.service_name}-{component}")
        else:
            setattr(record, 'appname', self.service_name)
        self.log_backoff()
        self.handler.emit(record)
