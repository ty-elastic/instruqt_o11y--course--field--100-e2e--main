import random
import ipaddress
import uuid
from datetime import datetime, timezone, timedelta

import ua_generator
from ua_generator.options import Options
from ua_generator.data.version import VersionRange
from faker import Faker

ERROR_RETRIES = 3

CHROME_VERSIONS = (125, 135)
BROWSER_PREFERENCE = ('chrome')
BROWSER_PREFERENCE_PERCENTAGE = 30

def generate_users_per_region(regions):
    users_per_region = {}
    fake = Faker()
    for region in regions.keys():
        users_per_region[region] = []
        for i in range(regions[region]['num_users']):
            name = fake.unique.first_name().lower() + "." + fake.unique.last_name().lower()
            user = { 'name': name }
            users_per_region[region].append(user)
    return users_per_region

def make_ua_generator_options():
    ua_generator_options = Options()
    ua_generator_options.weighted_versions = True
    ua_generator_options.version_ranges = {
        'chrome': VersionRange(CHROME_VERSIONS[0], CHROME_VERSIONS[1]),
    }
    return ua_generator_options

def generate_useragent_per_user(users_per_region, ua_generator_options):
    for region in users_per_region.keys():
        for user in users_per_region[region]:
            if random.randint(0,100) < BROWSER_PREFERENCE_PERCENTAGE:
                user['user_agent'] = ua_generator.generate(browser=BROWSER_PREFERENCE, options=ua_generator_options)
            else:
                user['user_agent'] = ua_generator.generate(options=ua_generator_options) 

def generate_ipaddress_per_user(users_per_region, regions):
    for region in users_per_region.keys():
        for user in users_per_region[region]:
            network = ipaddress.ip_network(regions[region]['client_ip_range'])
            ip_list = [str(ip) for ip in network]
            user['client_ip'] = random.choice(ip_list)

def get_users(*, metadata, region=None):
    users = []
    if region is not None:
        return metadata['users_per_region'][region]
    else:
        for region in metadata['users_per_region']:
            for user in metadata['users_per_region'][region]:
                users.append(user)
    return users

def generate_vars(metadata, global_state, thread_state, timestamp):
    vars = {}
    vars['region'] = random.choice(list(metadata['region'].keys()))
    vars['user'] = random.choice(metadata['users_per_region'][vars['region']])
    vars['client.ip'] = vars['user']['client_ip']
    vars['user.name'] = vars['user']['name']
    vars['client.user_agent'] = vars['user']['user_agent'].text
    vars['uuid'] = uuid.uuid4().hex
    vars['datetime_iso8601'] = timestamp.strftime("%Y-%m-%dT%H:%M:%SZ")

    if 'stock' in metadata:
        if 'stock' not in global_state:
            global_state['stock'] = {'symbols': {}}
            
        symbol = random.choice(list(metadata['stock']['symbols'].keys()))
        stock_metadata = metadata['stock']['symbols'][symbol]
        if symbol not in global_state['stock']['symbols']:
            global_state['stock']['symbols'][symbol] = {}
            global_state['stock']['symbols'][symbol]['stock_price'] = random.randrange(stock_metadata['price']['min'],stock_metadata['price']['max'])
        stock_state = global_state['stock']['symbols'][symbol]

        stock_state['stock_price'] = stock_state['stock_price'] + random.randrange(-stock_metadata['price']['swing'],stock_metadata['price']['swing'])
        if stock_state['stock_price'] <= stock_metadata['price']['min']:
            stock_state['stock_price'] = stock_metadata['price']['min']

        vars['stock.order'] = random.choice(metadata['stock']['orders'])
        vars['stock.symbol'] = symbol
        vars['stock.shares'] = random.randrange(1,100)
        vars['stock.price'] =  stock_state['stock_price']

    return vars

def generate_request_error_per_browser(*, global_state, metadata, browser, region, error=True):
    request_error_per_customer = global_state['request_error_per_customer']
    ua_generator_options = global_state['ua_generator_options']

    for browser_version_range in ua_generator_options.version_ranges.keys():
        if browser_version_range == browser:
            last_max = ua_generator_options.version_ranges[browser].max_version.major
            ua_generator_options.version_ranges = {
                browser: VersionRange(last_max+1, last_max+1)
            }

    users = get_users(metadata=metadata, region=region)
    for user in users:
        if user['user_agent'].browser == browser:
            print(f'new ua for {browser}')
            user['user_agent'] = ua_generator.generate(browser=browser, options=ua_generator_options)
            if error:
                print(f"start request error for customer {user['name']}")
                request_error_per_customer[user['name']] = {'amount': 100, 'retries': ERROR_RETRIES}
    
    return request_error_per_customer

def generate_exception(*, thread_state, item):
    print(f"new exception: {item}")
    thread_state['exceptions'].append(item)
    return thread_state['exceptions']

def get_exceptions(*, thread_state):
    return thread_state['exceptions']


def get_regions(global_metadata):
    return global_metadata['users_per_region'].keys()

def get_region(global_metadata, region):
    return global_metadata['region'][region]

def generate_global_metadata_and_state(config):
    global_state = {}
    global_state['ua_generator_options'] = make_ua_generator_options()
    global_state['request_error_per_customer'] = {}
    if 'stock' in config:
        global_state['stock_price'] = {}

    global_metadata = config['metadata']
    global_metadata['users_per_region'] = generate_users_per_region(global_metadata['region'])
    generate_useragent_per_user(global_metadata['users_per_region'], global_state['ua_generator_options'])
    generate_ipaddress_per_user(global_metadata['users_per_region'], global_metadata['region'])

    return global_metadata, global_state

def generate_thread_state():
    thread_state = {}
    thread_state['exceptions'] = []
    thread_state['messages'] = {}
    return thread_state