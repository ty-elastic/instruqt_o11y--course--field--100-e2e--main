from flask import Flask, request
import logging
import os
from kubernetes import client, config

app = Flask(__name__)
app.logger.setLevel(logging.INFO)

def init_otel(): 
    if 'OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED' in os.environ:
        print("enable otel logging")      
        root_logger = logging.getLogger()
        for handler in root_logger.handlers:
            if isinstance(handler, logging.StreamHandler):
                root_logger.removeHandler(handler)
init_otel()

def init_k8s():
    # Load in-cluster configuration
    config.load_incluster_config()
init_k8s()