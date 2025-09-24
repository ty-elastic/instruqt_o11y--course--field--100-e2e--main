from flask import Flask, request
import logging
import requests
import random
import time
import os
from threading import Thread
import concurrent.futures
import ipaddress

import ua_generator
from ua_generator.options import Options
from ua_generator.data.version import VersionRange
from faker import Faker

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

TRADE_TIMEOUT = 5
S_PER_DAY = 60
HIGH_TPUT_PCT = 95
LATENCY_SWING_MS = 10
HIGH_TPUT_SLEEP_MS = [2,3]
NORMAL_TPUT_SLEEP_MS = [200,300]
ERROR_TIMEOUT_S = 60
CONCURRENT_TRADE_REQUESTS = 20
NUM_CUSTOMERS_PER_REGION = 10

UNCLASSIFIED_LABEL = "unclassified"
TRAINING_TRADE_COUNT = 7500
TRAINING_PERCENT_LABELED = 75

CHROME_VERSIONS = (125, 135)
ua_generator_options = Options()
ua_generator_options.version_ranges = {
    'chrome': VersionRange(CHROME_VERSIONS[0], CHROME_VERSIONS[1]),
}

DAYS_OF_WEEK = ['M', 'Tu', 'W', 'Th', 'F']
ACTIONS = ['buy', 'sell', 'hold']

if os.environ['REGION'] == "1":
    print("region1")
    REGIONS = ['NA', 'LATAM']
elif os.environ['REGION'] == "2":
    print("region2")
    REGIONS = ['EU', 'EMEA', 'APAC']
else:
    print("region=all")
    REGIONS = ['NA', 'LATAM', 'EU', 'EMEA', 'APAC']

SYMBOLS = ['ZVZZT', 'ZALM', 'ZYX', 'CBAZ', 'BAA', 'OELK']

CLIENTIPS_PER_REGION = {
    'NA': '107.80.0.0/16',
    'LATAM': '186.189.224.0/20',
    'EU': '149.254.212.0/24',
    'EMEA': '102.65.16.0/20',
    'APAC': '103.107.52.0/24'
}

CUSTOMERS_PER_REGION = {}
def generate_customers_per_region():
    fake = Faker()
    for region in REGIONS:
        CUSTOMERS_PER_REGION[region] = []
        for i in range(NUM_CUSTOMERS_PER_REGION):
            name = fake.unique.first_name().lower() + "." + fake.unique.last_name().lower()
            CUSTOMERS_PER_REGION[region].append(name)
    #print(CUSTOMERS_PER_REGION)
generate_customers_per_region()

USER_SUBSCRIPTION = ['silver', 'gold', 'platinum']
SUBSCRIPTION_PER_USER = {}
def generate_subscription_per_user():
    for region in CUSTOMERS_PER_REGION.keys():
        for customer in CUSTOMERS_PER_REGION[region]:
            SUBSCRIPTION_PER_USER[customer] = random.choice(USER_SUBSCRIPTION)
    print(SUBSCRIPTION_PER_USER)
generate_subscription_per_user()

USERAGENTS_PER_USER = {}
def generate_useragent_per_user():
    for region in CUSTOMERS_PER_REGION.keys():
        for customer in CUSTOMERS_PER_REGION[region]:
            USERAGENTS_PER_USER[customer] = ua_generator.generate(options=ua_generator_options)
    #print(USERAGENTS_PER_USER)
generate_useragent_per_user()

IP_ADDRESS_PER_USER = {}
def generate_ipaddress_per_user():
    for region in CUSTOMERS_PER_REGION.keys():
        for customer in CUSTOMERS_PER_REGION[region]:
            network = ipaddress.ip_network(CLIENTIPS_PER_REGION[region])
            ip_list = [str(ip) for ip in network]
            IP_ADDRESS_PER_USER[customer] = random.choice(ip_list)
generate_ipaddress_per_user()

latency_per_action_per_region = {}
canary_per_region = {}
high_tput_per_customer = {}
high_tput_per_symbol = {}
high_tput_per_region = {}
request_error_per_customer = {}
db_error_per_region = {}
db_error_per_customer = {}
model_error_per_region = {}
skew_market_factor_per_symbol = {}

def get_customers():
    customers = []
    for region in CUSTOMERS_PER_REGION:
        for customer in CUSTOMERS_PER_REGION[region]:
            customers.append(customer)
    return customers

def bump_version_up_per_browser(*, browser, region):
    for browser_version_range in ua_generator_options.version_ranges.keys():
        if browser_version_range == browser:
            last_max = ua_generator_options.version_ranges[browser].max_version.major
            ua_generator_options.version_ranges = {
                browser: VersionRange(last_max+1, last_max+1)
            }

    if region is not None:
        customers = CUSTOMERS_PER_REGION[region]
    else:
        customers = get_customers()
    for customer in customers:
        if USERAGENTS_PER_USER[customer].browser == browser:
            print(f'new ua for {browser}')
            new_ua = ua_generator.generate(browser=browser, options=ua_generator_options)
            USERAGENTS_PER_USER[customer] = new_ua

def conform_request_bool(value):
    return value.lower() == 'true'

def generate_trade_request(*, subscription, customer_id, symbol, day_of_week, region, latency_amount, latency_action, error_model, error_db, error_db_service, error_request, skew_market_factor, canary, classification=None, data_source):
    try:
        params={'symbol': symbol, 
                'day_of_week': day_of_week,
                'subscription': subscription,
                'customer_id': customer_id, 
                'latency_amount': latency_amount,
                'latency_action': latency_action,
                'region': region,
                'error_model': error_model,
                'error_db': error_db,
                'error_db_service': error_db_service,
                'error_request': error_request,
                'skew_market_factor': skew_market_factor,
                'canary': canary,
                'data_source': data_source}
        if classification is not None:
            params['classification'] = classification

        headers = {}
        headers["X-Forwarded-For"] = IP_ADDRESS_PER_USER[customer_id]
        if customer_id is not None and customer_id in USERAGENTS_PER_USER:
            headers['User-Agent']= USERAGENTS_PER_USER[customer_id].text

        if error_request is True:
            del params['customer_id']
            params['customerid'] = customer_id
            
        trade_response = requests.post(f"http://{os.environ['TRADER_SERVICE']}/trade/request", 
                                       json=params,
                                       headers=headers,
                                       timeout=TRADE_TIMEOUT)
        trade_response.raise_for_status()
    except Exception as inst:
        print(inst)

def generate_trade_requests():
    idx_of_week = 0
    day_start = 0
    next_region = None
    next_customer = None
    next_symbol = None
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=CONCURRENT_TRADE_REQUESTS) as executor:
        while True:
            now = time.time()
            if now - day_start >= S_PER_DAY:
                idx_of_week = (idx_of_week + 1) % len(DAYS_OF_WEEK)
                app.logger.info(f"advance to {DAYS_OF_WEEK[idx_of_week]}")
                day_start = now

            sleep = float(random.randint(NORMAL_TPUT_SLEEP_MS[0], NORMAL_TPUT_SLEEP_MS[1]) / 1000)
            
            region = next_region if next_region is not None else random.choice(list(CUSTOMERS_PER_REGION.keys()))
            symbol = next_symbol if next_symbol is not None else random.choice(SYMBOLS)
            customer_id = next_customer if next_customer is not None else random.choice(CUSTOMERS_PER_REGION[region])
            subscription = SUBSCRIPTION_PER_USER[customer_id]

            if region in latency_per_action_per_region:
                latency_amount = random.randint(latency_per_action_per_region[region]['amount']-LATENCY_SWING_MS, latency_per_action_per_region[region]['amount']+LATENCY_SWING_MS) / 1000.0
                latency_action = latency_per_action_per_region[region]['action']
                if latency_per_action_per_region[region]['oneshot'] and time.time() - latency_per_action_per_region[region]['start'] >= ERROR_TIMEOUT_S:
                    app.logger.info(f"latency_per_action_per_region[{region}] timeout")
                    latency_region_delete(region)
            else:
                latency_amount = 0
                latency_action = None

            if region in model_error_per_region:
                error_model = True if random.randint(0, 100) > (100-model_error_per_region[region]['amount']) else False
                if time.time() - model_error_per_region[region]['start'] >= ERROR_TIMEOUT_S:
                    app.logger.info(f"db_error_per_region[{region}] timeout")
                    err_model_region_delete(region)
            else:
                error_model = False

            if customer_id in request_error_per_customer:
                error_request = True if random.randint(0, 100) > (100-request_error_per_customer[customer_id]['amount']) else False
                if request_error_per_customer[customer_id]['oneshot'] and time.time() - request_error_per_customer[customer_id]['start'] >= ERROR_TIMEOUT_S:
                    app.logger.info(f"request_error_per_customer[{customer_id}] timeout")
                    err_request_customer_delete(customer_id)
            else:
                error_request = False

            if customer_id in db_error_per_customer:
                error_db = True if random.randint(0, 100) > (100-db_error_per_customer[customer_id]['amount']) else False
                if 'service' in db_error_per_customer[customer_id]:
                    error_db_service = db_error_per_customer[customer_id]['service']
                else:
                    error_db_service = None
                if db_error_per_customer[customer_id]['oneshot'] and time.time() - db_error_per_customer[customer_id]['start'] >= ERROR_TIMEOUT_S:
                    app.logger.info(f"db_error_per_customer[{customer_id}] timeout")
                    err_db_customer_delete(region)
            elif region in db_error_per_region:
                error_db = True if random.randint(0, 100) > (100-db_error_per_region[region]['amount']) else False
                if 'service' in db_error_per_region[region]:
                    error_db_service = db_error_per_region[region]['service']
                else:
                    error_db_service = None
                if time.time() - db_error_per_region[region]['start'] >= ERROR_TIMEOUT_S:
                    app.logger.info(f"db_error_per_region[{region}] timeout")
                    err_db_region_delete(region)
            else:
                error_db = False
                error_db_service = None

            if symbol in skew_market_factor_per_symbol:
                skew_market_factor = skew_market_factor_per_symbol[symbol]
            else:
                skew_market_factor = 0

            if region in canary_per_region:
                canary = True
            else:
                canary = False

            app.logger.info(f"trading {symbol} for {customer_id} on {DAYS_OF_WEEK[idx_of_week]} from {region} with latency {latency_amount}, error_model={error_model}, error_request={error_request}, error_db={error_db}, skew_market_factor={skew_market_factor}, canary={canary}")

            executor.submit(generate_trade_request, subscription=subscription, customer_id=customer_id, symbol=symbol, day_of_week=DAYS_OF_WEEK[idx_of_week], region=region,
                        latency_amount=latency_amount, latency_action=latency_action, 
                        error_model=error_model, 
                        error_db=error_db, error_db_service=error_db_service, error_request=error_request,
                        skew_market_factor=skew_market_factor, canary=canary,
                        data_source='monkey')

            next_region = None
            if len(high_tput_per_region.keys()) > 0:
                next_high_tput_region = random.choice(list(high_tput_per_region.keys()))
                next_region = next_high_tput_region if random.randint(0, 100) > (100-high_tput_per_region[next_high_tput_region]) else None
                if next_region is not None:
                    sleep = float(random.randint(HIGH_TPUT_SLEEP_MS[0], HIGH_TPUT_SLEEP_MS[1]) / 1000)
            
            next_customer = None
            if len(high_tput_per_customer.keys()) > 0:
                next_high_tput_customer = random.choice(list(high_tput_per_customer.keys()))
                next_customer = next_high_tput_customer if random.randint(0, 100) > (100-high_tput_per_customer[next_high_tput_customer]) else None
                if next_customer is not None:
                    sleep = float(random.randint(HIGH_TPUT_SLEEP_MS[0], HIGH_TPUT_SLEEP_MS[1]) / 1000)

            next_symbol = None
            if len(high_tput_per_symbol.keys()) > 0:
                next_high_tput_symbol = random.choice(list(high_tput_per_symbol.keys()))
                next_symbol = next_high_tput_symbol if random.randint(0, 100) > (100-high_tput_per_symbol[next_high_tput_symbol]) else None
                if next_symbol is not None:
                    sleep = float(random.randint(HIGH_TPUT_SLEEP_MS[0], HIGH_TPUT_SLEEP_MS[1]) / 1000)

            time.sleep(sleep)

@app.route('/health')
def health():
    return f"KERNEL OK"

@app.post('/reset/market')
def reset_market():
    global high_tput_per_customer
    global high_tput_per_symbol
    global high_tput_per_region
    global skew_market_factor_per_symbol
    
    high_tput_per_customer = {}
    high_tput_per_symbol = {}
    high_tput_per_region = {}
    skew_market_factor_per_symbol = {}
    
    app.logger.info(f"market reset")
    return "OK"

@app.post('/reset/error')
def reset_error():
    global latency_per_action_per_region
    global db_error_per_region
    global model_error_per_region
    global db_error_per_customer
    global request_error_per_customer
    
    latency_per_action_per_region = {}
    db_error_per_region = {}
    model_error_per_region = {}
    db_error_per_customer = {}
    request_error_per_customer = {}

    app.logger.info(f"error reset")
    return "OK"

@app.post('/reset/test')
def test_error():
    global canary_per_region

    canary_per_region = {}
    
    app.logger.info(f"test reset")
    return "OK"

@app.get('/state')
def get_state():
    state = {
        'days_of_week': DAYS_OF_WEEK,
        'customers': get_customers(),
        'symbols': SYMBOLS,
        'regions': list(CUSTOMERS_PER_REGION.keys()),
        
        'latency_per_action_per_region': latency_per_action_per_region,
        'canary_per_region': canary_per_region,
        'high_tput_per_customer': high_tput_per_customer,
        'high_tput_per_symbol': high_tput_per_symbol,
        'high_tput_per_region': high_tput_per_region,
        'db_error_per_region': db_error_per_region,
        'db_error_per_customer': db_error_per_customer,
        'request_error_per_customer': request_error_per_customer,
        'model_error_per_region': model_error_per_region,
        'skew_market_factor_per_symbol': skew_market_factor_per_symbol
    }
    return state

@app.post('/tput/region/<region>/<speed>')
def tput_region(region, speed):
    global high_tput_per_region
    high_tput_per_region[region] = HIGH_TPUT_PCT
    return high_tput_per_region
@app.delete('/tput/region/<region>')
def tput_region_delete(region):
    if region in high_tput_per_region:
        del high_tput_per_region[region]
    return high_tput_per_region

@app.post('/tput/customer/<customer>/<speed>')
def tput_customer(customer, speed):
    global high_tput_per_customer
    high_tput_per_customer[customer] = HIGH_TPUT_PCT
    return high_tput_per_customer
@app.delete('/tput/customer/<customer>')
def tput_customer_delete(customer):
    if customer in high_tput_per_customer:
        del high_tput_per_customer[customer]
    return high_tput_per_customer

@app.post('/tput/symbol/<symbol>/<speed>')
def tput_symbol(symbol, speed):
    global high_tput_per_symbol
    high_tput_per_symbol[symbol] = HIGH_TPUT_PCT
    return high_tput_per_symbol
@app.delete('/tput/symbol/<symbol>')
def tput_symbol_delete(symbol):
    global high_tput_per_symbol
    if symbol in high_tput_per_symbol:
        del high_tput_per_symbol[symbol]
    return high_tput_per_symbol

@app.post('/latency/region/<region>/<amount>')
def latency_region(region, amount):
    app.logger.info(f"latency start {region}={amount}") 

    global latency_per_action_per_region
    latency_action = request.args.get('latency_action', default=None, type=str)
    latency_oneshot = request.args.get('latency_oneshot', default=True, type=conform_request_bool)
    latency_per_action_per_region[region] = {'action': latency_action, 'amount': int(amount), 'start': time.time(), 'oneshot': latency_oneshot}
    if latency_oneshot:
        high_tput_per_region[region] = HIGH_TPUT_PCT
    return latency_per_action_per_region    
@app.delete('/latency/region/<region>')
def latency_region_delete(region):
    app.logger.info(f"latency stop {region}") 

    global latency_per_action_per_region
    if region in latency_per_action_per_region:
        del latency_per_action_per_region[region]
    if region in high_tput_per_region:
        del high_tput_per_region[region]
    return latency_per_action_per_region    

@app.post('/err/db/region/<region>/<amount>')
def err_db_region(region, amount):
    global db_error_per_region
    err_db_service = request.args.get('err_db_service', default=None, type=str)
    db_error_per_region[region] = {'service': err_db_service, 'amount': int(amount), 'start': time.time()}
    high_tput_per_region[region] = HIGH_TPUT_PCT
    return db_error_per_region
@app.delete('/err/db/region/<region>')
def err_db_region_delete(region):
    global db_error_per_region
    if region in db_error_per_region:
        del db_error_per_region[region]
    if region in high_tput_per_region:
        del high_tput_per_region[region]
    return db_error_per_region

@app.post('/err/db/customer/<customer>/<amount>')
def err_db_customer(customer, amount):
    global db_error_per_customer
    err_db_service = request.args.get('err_db_service', default=None, type=str)
    err_db_oneshot = request.args.get('err_db_oneshot', default=True, type=conform_request_bool)
    db_error_per_customer[customer] = {'service': err_db_service, 'amount': int(amount), 'start': time.time(), 'oneshot': err_db_oneshot}
    if err_db_oneshot:
        high_tput_per_customer[customer] = HIGH_TPUT_PCT
    return db_error_per_customer
@app.delete('/err/db/customer/<customer>')
def err_db_customer_delete(customer):
    global db_error_per_customer
    if customer in db_error_per_customer:
        del db_error_per_customer[customer]
    if customer in high_tput_per_customer:
        del high_tput_per_customer[customer]
    return db_error_per_customer

@app.post('/err/browser/<browser>')
def err_request_ua(browser):
    global request_error_per_customer
    err_request_oneshot = request.args.get('err_request_oneshot', default=False, type=conform_request_bool)
    region = request.args.get('region', default=None, type=str)

    bump_version_up_per_browser(browser=browser, region=region)
    if region is not None:
        customers = CUSTOMERS_PER_REGION[region]
    else:
        customers = get_customers()
    for customer in customers:
        if USERAGENTS_PER_USER[customer].browser == browser:
            print(f"start request error for customer {customer}")
            request_error_per_customer[customer] = {'amount': 100, 'start': time.time(), 'oneshot': err_request_oneshot}
            if err_request_oneshot:
                high_tput_per_customer[customer] = HIGH_TPUT_PCT
    return request_error_per_customer
@app.delete('/err/ua/region/<region>')
def err_request_customer_delete(browser):
    global request_error_per_customer
    for customer in request_error_per_customer:
        if USERAGENTS_PER_USER[customer].browser == browser:
            print(f"stop request error for customer {customer}")
            del request_error_per_customer[customer]
            if customer in high_tput_per_customer:
                del high_tput_per_customer[customer]
    return request_error_per_customer

@app.post('/err/model/region/<region>/<amount>')
def err_model_region(region, amount):
    global model_error_per_region
    model_error_per_region[region] = {'amount': int(amount), 'start': time.time()}
    high_tput_per_region[region] = HIGH_TPUT_PCT
    return model_error_per_region    
@app.delete('/err/model/region/<region>')
def err_model_region_delete(region):
    global model_error_per_region
    if region in model_error_per_region:
        del model_error_per_region[region]
    if region in high_tput_per_region:
        del high_tput_per_region[region]
    return model_error_per_region

@app.post('/skew_market_factor/symbol/<symbol>/<amount>')
def skew_market_factor_symbol(symbol, amount):
    global skew_market_factor_per_symbol
    skew_market_factor_per_symbol[symbol] = int(amount)
    return skew_market_factor_per_symbol
@app.delete('/skew_market_factor/symbol/<symbol>')
def skew_pr_symbol_delete(symbol):
    global skew_market_factor_per_symbol
    if symbol in skew_market_factor_per_symbol:
        del skew_market_factor_per_symbol[symbol]
    return skew_market_factor_per_symbol

@app.post('/canary/region/<region>')
def canary_region(region):
    global canary_per_region
    canary_per_region[region] = True
    return canary_per_region    
@app.delete('/canary/region/<region>')
def canary_region_delete(region):
    global canary_per_region
    if region in canary_per_region:
        del canary_per_region[region]
    return canary_per_region  

def generate_trade_force(*, subscription, customer_id, day_of_week, region, symbol, action, shares, share_price, data_source, classification):
    try:

        headers = {}
        headers["X-Forwarded-For"] = IP_ADDRESS_PER_USER[customer_id]
        if customer_id is not None and customer_id in USERAGENTS_PER_USER:
            headers['User-Agent']= USERAGENTS_PER_USER[customer_id].text

        trade_response = requests.post(f"http://{os.environ['TRADER_SERVICE']}/trade/force", 
                                       headers=headers,
                                       json={'symbol': symbol,
                                               'day_of_week': day_of_week, 
                                               'shares': shares, 
                                               'action': action,
                                               'region': region,
                                               'customer_id': customer_id,
                                               'subscription': subscription,
                                               'share_price': share_price,
                                               'data_source': data_source,
                                               'classification': classification
                                               },
                                       timeout=TRADE_TIMEOUT)
        trade_response.raise_for_status()
    except Exception as inst:
        print(inst)

def generate_trades(*, fixed_day_of_week=None, fixed_region = None, fixed_symbol = None,
                    fixed_action = None, fixed_shares_min = None, fixed_shares_max = None,
                    fixed_share_price_min = None, fixed_share_price_max = None, classification, data_source):

    app.logger.info(f"using {CONCURRENT_TRADE_REQUESTS} workers") 
    with concurrent.futures.ThreadPoolExecutor(max_workers=CONCURRENT_TRADE_REQUESTS) as executor:

        for x in range(0, TRAINING_TRADE_COUNT):

            label_rand = random.randint(1, 100)
            if label_rand < TRAINING_PERCENT_LABELED:
                trade_classification = classification
            else:
                trade_classification = 'unclassified'

            day_of_week = random.choice(DAYS_OF_WEEK)
            if label_rand < TRAINING_PERCENT_LABELED and fixed_day_of_week is not None:
                day_of_week = random.choice(fixed_day_of_week)

            region = random.choice(list(CUSTOMERS_PER_REGION.keys()))
            if label_rand < TRAINING_PERCENT_LABELED and fixed_region is not None:
                region = random.choice(fixed_region)

            symbol = random.choice(SYMBOLS)
            if label_rand < TRAINING_PERCENT_LABELED and fixed_symbol is not None:
                symbol = random.choice(fixed_symbol)

            customer_id = random.choice(CUSTOMERS_PER_REGION[region])
            subscription = SUBSCRIPTION_PER_USER[customer_id]
                
            action = random.choice(ACTIONS)
            if label_rand < TRAINING_PERCENT_LABELED and fixed_action is not None:
                action = random.choice(fixed_action) 

            shares = random.randint(1, 100)
            if label_rand < TRAINING_PERCENT_LABELED and fixed_shares_min is not None:
                shares = random.randint(fixed_shares_min, fixed_shares_max)

            share_price = random.randint(1, 1000)
            if label_rand < TRAINING_PERCENT_LABELED and fixed_share_price_min is not None:
                share_price = random.randint(fixed_share_price_min, fixed_share_price_max)

            app.logger.info(f"training {symbol} for {customer_id} on {day_of_week} from {region}, classification {trade_classification}, data_source {data_source}")

            executor.submit(generate_trade_force, symbol=symbol, day_of_week=day_of_week, region=region, subscription=subscription, customer_id=customer_id,
                                action=action, shares=shares, share_price=share_price, classification=trade_classification,
                                data_source=data_source)

            sleep = float(random.randint(HIGH_TPUT_SLEEP_MS[0], HIGH_TPUT_SLEEP_MS[1]) / 1000)
            time.sleep(sleep)

@app.post('/train/<classification>')
def train_label(classification):

    body = request.get_json()
    #app.logger.warn(body)

    if 'day_of_week' in body:
        day_of_week = body['day_of_week']
    else:
        day_of_week = None

    if 'region' in body:
        region = body['region']
    else:
        region = None

    if 'action' in body:
        action = body['action']
    else:
        action = None

    if 'symbol' in body:
        symbol = body['symbol']
    else:
        symbol = None

    if 'shares_min' in body:
        shares_min = body['shares_min']
    else:
        shares_min = None

    if 'shares_max' in body:
        shares_max = body['shares_max']
    else:
        shares_max = None

    if 'share_price_min' in body:
        share_price_min = body['share_price_min']
    else:
        share_price_min = None

    if 'share_price_max' in body:
        share_price_max = body['share_price_max']
    else:
        share_price_max = None

    if 'data_source' in body:
        data_source = body['data_source']
    else:
        data_source = None

    generate_trades(fixed_day_of_week=day_of_week, fixed_region = region, fixed_symbol = symbol,
                    fixed_action = action, fixed_shares_min = shares_min, fixed_shares_max = shares_max, 
                    fixed_share_price_min=share_price_min, fixed_share_price_max=share_price_max, 
                    classification=classification, data_source=data_source)
    
    return "OK"


# wait 10s before starting
time.sleep(5)
Thread(target=generate_trade_requests, daemon=False).start()
