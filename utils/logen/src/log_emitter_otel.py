import time
import logging
import os
import uuid
from log_emitter import LogEmitter

from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler, LogRecord
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.sdk.resources import Resource

BACKLOG_Q_SEND_DELAY = 0.01
BACKLOG_Q_TIME_S = 60 * 60
BACKLOG_Q_BATCH_S = 60 * 2
BACKLOG_Q_TIMEOUT_MS = 10

DEBUG = True

class LogOtel(LogEmitter):
    def __init__(self, *, service_name, max_logs_per_second, regional_attributes, language, mode=None):
        super().__init__(service_name=service_name, max_logs_per_second=max_logs_per_second, regional_attributes=regional_attributes, language=language, mode=mode)

        if not DEBUG:
            attributes = {
                "service.name": service_name,

                "k8s.container.name": service_name,
                "k8s.namespace.name": "default",
                "k8s.deployment.name": service_name,
                "k8s.pod.uid": uuid.uuid4().hex,
                "k8s.pod.name": f"{service_name}-{uuid.uuid4().hex}",

                "container.id": uuid.uuid4().hex
            }
            if mode == 'wired':
                attributes['elasticsearch.index'] = 'logs'
            else:
                attributes['data_stream.dataset'] = service_name
            if language is not None:
                attributes["telemetry.sdk.language"] = language
            host_uuid = uuid.uuid4().hex
            for key in regional_attributes.keys():
                regional_attributes[key] = regional_attributes[key].replace("{host_uuid}", host_uuid)
            attributes.update(regional_attributes)
            logger_provider = LoggerProvider(
                resource=Resource.create(attributes),
            )
            if 'COLLECTOR_ADDRESS' in os.environ:
                address = os.environ['COLLECTOR_ADDRESS']
            else:
                address = "collector"
            print(f"sending logs to http://{address}:4317 for {service_name}, {regional_attributes['cloud.availability_zone']}")
            otlp_exporter = OTLPLogExporter(endpoint=f"http://{address}:4317", insecure=True)
            processor = BatchLogRecordProcessor(
                otlp_exporter,
                schedule_delay_millis=BACKLOG_Q_TIMEOUT_MS,
                max_queue_size=BACKLOG_Q_TIME_S * max_logs_per_second,
                max_export_batch_size=BACKLOG_Q_BATCH_S * max_logs_per_second,
            )
            logger_provider.add_log_record_processor(processor)
            self.handler = LoggingHandler(level=logging.NOTSET, logger_provider=logger_provider)
        else:
            self.handler = logging.StreamHandler()
        self.logger = logging.getLogger(service_name)
        self.logger.addHandler(self.handler)
        self.logger.setLevel(logging.INFO)

    def log_backoff(self):
        if self.processor is not None:
            while len(self.processor._batch_processor._queue) == self.processor._batch_processor._max_queue_size:
                time.sleep(BACKLOG_Q_SEND_DELAY)
                #print('blocked')



