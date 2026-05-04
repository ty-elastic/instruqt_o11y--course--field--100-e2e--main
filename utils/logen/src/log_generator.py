from datetime import datetime, timezone, timedelta
import random
import time

import metadata_generator

DEBUG = True
ERROR_RETRIES = 3

g_realtime = {}

def get_realtime():
    global g_realtime
    retval = True
    for thread_name in g_realtime.keys():
        if g_realtime[thread_name] is False:
            retval = False

    return retval

def form_nginx_line(*, ip, timestamp, method, url, protocol, status_code, size, ref_url, user_agent):
    line = f"{ip} - - [{timestamp}] \"{method} {url} {protocol}\" {status_code} {size} \"{ref_url}\" \"{user_agent}\"\n"
    return line

def generate_nginx_line(*, vars, timestamp, metadata, global_state):
    lines = []

    request_error_per_customer = global_state['request_error_per_customer']
    user = vars['user']

    api = random.choice(metadata['api']) 
    url=api['endpoint']
    size=random.randrange(api['payload']['min'], api['payload']['max'])

    retries = 1
    if user['name'] in request_error_per_customer:
        error_request = True if random.randint(0, 100) > (100-request_error_per_customer[user['name']]['amount']) else False
        if error_request:
            retries = request_error_per_customer[user['name']]['retries']
    else:
        error_request = False

    send_timestamp = timestamp
    for i in range(retries):
        #timestamp_str = send_timestamp.strftime("%d/%b/%Y:%H:%M:%S %z")
        timestamp_str = send_timestamp.strftime("%Y-%m-%dT%H:%M:%SZ")

        line = form_nginx_line(ip=user['client_ip'],
                            timestamp=timestamp_str,
                            method='POST',
                            url=url,
                            protocol='HTTP/1.1',
                            status_code=200 if error_request is False else 500,
                            size=size,
                            ref_url='-',
                            user_agent=user['user_agent'].text)
        lines.append({'body': line, 'level': "INFO"})
        send_timestamp = send_timestamp + timedelta(seconds=1/1000)
    return lines, error_request, False

def var_substitute_line(*, vars, template):
    for k,v in vars.items():
        if not isinstance(v, dict):
            template = template.replace("{" + k + "}", str(v))

    return template

def get_exception_message(timestamp, vars, thread_state):
    in_exception = False
    src_messages_id = None
    exceptions_indices_to_remove = []
    for index, exception in enumerate(thread_state['exceptions']):

        if exception['reset'] == False and 'stop_timestamp' in exception and timestamp >= exception['stop_timestamp']:
            print(f"stopping exception {exception}")
            if 'repeat' not in exception:
                exceptions_indices_to_remove.append(index)
            else:
                exception['reset'] = True
                if exception['repeat']['min_minutes'] == exception['repeat']['max_minutes']:
                    exception['start_timestamp'] = timestamp + timedelta(minutes=exception['repeat']['min_minutes'])
                else:
                    exception['start_timestamp'] = timestamp + timedelta(minutes=random.randrange(exception['repeat']['min_minutes'],exception['repeat']['max_minutes']))
            continue

        if 'start_timestamp' not in exception:
            exception['reset'] = True
            exception['start_timestamp'] = timestamp

        if exception['start_timestamp'] <= timestamp:
            if exception['reset'] == True:
                print(f"starting exception {exception}")
                exception['reset'] = False
                if 'duration_minutes' in exception:
                    exception['stop_timestamp'] = timestamp + timedelta(minutes=exception['duration_minutes'])
        else:
            continue

        in_exception = True

        if 'filter' in exception:
            if ('region' in exception['filter'] and exception['filter']['region'] != vars['region']):
                continue
            if 'percent' in exception['filter'] and random.randint(0, 100) < (100-exception['filter']['percent']):
                continue
        src_messages_id = exception['messages']
        break
    for index in exceptions_indices_to_remove:
        del thread_state['exceptions'][index]

    return src_messages_id, in_exception

def generate_service_line(*, vars, timestamp, metadata, service, messages, thread_state):
    lines = []

    exception_message = False
    src_messages_id, in_exception = get_exception_message(timestamp, vars, thread_state)
    if src_messages_id is None:
        src_messages_id = service['messages']
    else:
        exception_message = True
    src_messages = messages[src_messages_id]

    if src_messages['order'] == 'random':
        message = random.choice(src_messages['lines'])
    elif src_messages['order'] == 'loop':
        idx = thread_state['messages'][src_messages_id]['idx']
        message = src_messages['lines'][idx]
        if idx == len(src_messages['lines'])-1:
            thread_state['messages'][src_messages_id]['idx'] = 0
        else:
            thread_state['messages'][src_messages_id]['idx'] = idx + 1

    lines.append(message)
    return lines, exception_message, in_exception

def generate(*, thread, thread_name, generator, loggers, start_timestamp, end_timestamp, logs_per_second, metadata, thread_state, global_state, messages):
    global g_realtime

    timestamp = start_timestamp
    g_realtime[thread_name] = timestamp > datetime.now(tz=timezone.utc)

    for index, exception in enumerate(thread_state['exceptions']):
        exception['reset'] = False

    while timestamp < end_timestamp if end_timestamp is not None else True:
        vars = metadata_generator.generate_vars(metadata, global_state, thread_state, timestamp)

        lines = []
        if generator['type'] == 'nginx':
            lines, exception_message, in_exception = generate_nginx_line(vars=vars, timestamp=timestamp, metadata=metadata, global_state=global_state)
        elif generator['type'] == 'service':
            lines, exception_message, in_exception = generate_service_line(vars=vars, timestamp=timestamp, metadata=metadata, service=generator, messages=messages, thread_state=thread_state)

        current_logs_per_second = logs_per_second
        if in_exception and 'logs_per_second' in exception:    
            current_logs_per_second = exception['logs_per_second']

        for line in lines:
            if thread['format'] == 'raw':
                line = {'body': '{datetime_iso8601} [' + line['level'] + '] ' + line['body'], 'level': "INFO"}
            line['body'] = var_substitute_line(vars=vars, template=line['body'])
            loggers[vars['region']].log(timestamp, line['level'], line['body'], line['node'] if 'node' in line else None, line['component'] if 'component' in line else None)

        if timestamp > datetime.now(tz=timezone.utc):
            if not g_realtime[thread_name]:
                print(f"{thread_name} realtime reached")
                g_realtime[thread_name] = True

            wallclock = datetime.now(tz=timezone.utc)
            #print(f"wall={wallclock.timestamp()},time={timestamp.timestamp()}")
            delta = wallclock.timestamp() - timestamp.timestamp()
            # leading
            if delta < 0:
                time.sleep(abs(delta))

        timestamp = timestamp + timedelta(seconds=1/current_logs_per_second)
    return timestamp
