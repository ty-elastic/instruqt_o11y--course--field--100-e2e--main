from flask import Flask, request, abort
from datetime import datetime, timezone, timedelta
import logging
from threading import Thread
import yaml
import time
import csv

import log_generator
import log_emitter_syslog
import log_emitter_otel
import metadata_generator

g_global_metadata = {}
g_global_state = {}
g_thread_state = {}

app = Flask(__name__)
app.logger.setLevel(logging.INFO)

@app.get('/status/realtime')
def get_realtime():
    retval = log_generator.get_realtime()
    if retval:
        return {"realtime": True}
    else:
        abort(404, description="not realtime")

@app.post('/err/browser/<browser>')
def err_request_ua(browser):
    global g_global_metadata
    region = request.args.get('region', default=None, type=str)
    return metadata_generator.generate_request_error_per_browser(browser=browser, region=region, metadata=g_global_metadata, global_state=g_global_state)

@app.post('/err/exception/<thread_name>/<messages>')
def err_exception(thread_name, messages):
    global g_thread_state

    region = request.args.get('region', None, str)
    percent = request.args.get('percent', 100, int)
    duration_minutes = request.args.get('duration_minutes', None, int)

    item = {
        'type': "generate_exception",
        'messages': messages,
        'filter': {
            'percent': percent
        }
    }

    if region is not None:
        item['filter']['region'] = region
    if duration_minutes is not None:
        item['duration_minutes'] = duration_minutes

    return metadata_generator.generate_exception(thread_state=g_thread_state[thread_name], item=item)

def prepare_messages(thread_messages, thread_state):
    for message_name, messages in thread_messages.items():
        if 'file' in messages:
            messages['lines'] = []
            with open(messages['file']['path'], 'r', newline='') as file:
                if messages['file']['type'] == 'csv':
                    reader = csv.DictReader(file)
                    for row in reader:
                        if 'level' in messages['file']:
                            row['Level'] = messages['file']['level']
                        message = {'body': row['Content'], 'level': row['Level']}
                        if 'Node' in row:
                            message['node'] = row['Node']
                        if 'Component' in row:
                            message['component'] = row['Component']
                        if 'eventids' not in messages['file'] or row['EventId'] in messages['file']['eventids']:
                            messages['lines'].append(message)
        if 'order' not in messages:
            messages['order'] = 'random'
        else:
            thread_state['messages'][message_name] = {'idx': 0}



def make_loggers(*, service_name, max_logs_per_second, metadata, language, mode=None, output='otlp'):
    loggers = {}

    for region in metadata_generator.get_regions(metadata):
        if output == 'otlp':
            loggers[region] = log_emitter_otel.LogOtel(service_name=service_name, max_logs_per_second=max_logs_per_second, 
                                    regional_attributes=metadata_generator.get_region(metadata, region)['resource_attributes'],
                                    language=language, mode=mode)
        elif output == 'syslog':
            loggers[region] = log_emitter_syslog.LogSyslog(service_name=service_name, max_logs_per_second=max_logs_per_second, 
                                    regional_attributes=metadata_generator.get_region(metadata, region)['resource_attributes'],
                                    language=language, mode=mode)
    return loggers

def run_schedule(thread, global_metadata, global_state, thread_state):
    if 'metadata' not in thread:
        thread['metadata'] = {}
    if 'messages' not in thread:
        thread['messages'] = {}
    if 'language' not in thread:
        thread['language'] = 'unknown'
    if 'mode' not in thread:
        thread['mode'] = 'classic'
    if 'format' not in thread:
        thread['format'] = 'structured'

    schedule = thread['schedule']
    thread_name = thread['name']
    thread_messages = thread['messages']
    metadata = global_metadata | thread['metadata']

    prepare_messages(thread_messages, thread_state)

    max_lps = 0
    for item in schedule:
        print(f'{item}')
        if 'logs_per_second' in item:
            max_lps = max(max_lps, item['logs_per_second'])

    loggers = make_loggers(service_name=thread_name, max_logs_per_second=max_lps, metadata=metadata, language=thread['language'], mode=thread['mode'], output=thread['output'])

    last_ts = schedule_start = datetime.now(tz=timezone.utc)
    print(f'start @ {schedule_start}')
    for item in schedule:
        if 'template' not in item:
            item['template'] = None

        if item['type'] == 'nginx' or item['type'] == 'service':

            if 'backfill_start_minutes' in item:
                start = schedule_start - timedelta(minutes=item['backfill_start_minutes'])
            else:
                start = last_ts

            if 'backfill_duration_minutes' in item:
                stop = schedule_start - timedelta(minutes=item['backfill_duration_minutes'])
            elif 'duration_minutes' in item:
                stop = start + timedelta(minutes=item['duration_minutes'])
            else:
                stop = None

            print(f'type={item['type']}, start={start}, stop={stop}, interval_s={1/item['logs_per_second']}')
            last_ts = log_generator.generate(thread=thread, thread_name=thread_name, generator=item, loggers=loggers, start_timestamp=start,
                               end_timestamp=stop, logs_per_second=item['logs_per_second'],
                               metadata=metadata, messages=thread_messages, thread_state=thread_state, global_state=global_state)

        elif item['type'] == 'nginx_ua_request_errors':
            metadata_generator.generate_request_error_per_browser(browser=item['browser'], region=item['region'], metadata=metadata, global_state=global_state)

        elif item['type'] == 'generate_exception':
            metadata_generator.generate_exception(item=item, thread_state=thread_state)

def load_config():
    try:
        with open('config/logen.yaml', 'r') as file:
            data = yaml.safe_load(file)
            return data
    except FileNotFoundError:
        print("Error: 'otel-logen.yaml' not found.")
    except yaml.YAMLError as e:
        print(f"Error parsing YAML: {e}")

def run_threads(config):
    global g_global_metadata
    global g_global_state
    global g_thread_state

    g_global_metadata, g_global_state = metadata_generator.generate_global_metadata_and_state(config)

    threads = []
    for thread in config['threads']:
        g_thread_state[thread['name']] = metadata_generator.generate_thread_state()
        t = Thread(target=run_schedule, args=[thread, g_global_metadata, g_global_state, g_thread_state[thread['name']]], daemon=False)
        t.start()
        threads.append(t)
    for t in threads:
        t.join()

config = load_config()
time.sleep(1)
t = Thread(target=run_threads,  args=[config], daemon=False)
t.start()

if __name__ == "__main__":
    t.join()
