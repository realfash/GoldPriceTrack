from flask import Flask, jsonify, send_from_directory, request
from flask_cors import CORS
import requests
import threading
import time
from datetime import datetime, timedelta
import os
import random

app = Flask(__name__, static_folder='public', static_url_path='')
CORS(app)

METALS_CONFIG = {
    'gold': {
        'name': '黄金',
        'secid': '113.AU2606',
        'unit': 'g',
        'icon': '🥇'
    },
    'silver': {
        'name': '白银',
        'secid': '113.AG2606',
        'unit': 'kg',
        'icon': '🥈'
    },
    'platinum': {
        'name': '铂金',
        'secid': '113.SP2606',
        'unit': 'g',
        'icon': '⚪'
    },
    'palladium': {
        'name': '钯金',
        'secid': '113.PD2606',
        'unit': 'g',
        'icon': '🔵'
    }
}

price_cache = {}
MAX_HISTORY = 500

def fetch_metal_price(metal_type):
    config = METALS_CONFIG.get(metal_type)
    if not config:
        return None
    
    try:
        print(f'[{datetime.now().strftime("%Y-%m-%d %H:%M:%S")}] Fetching {config["name"]} price from Eastmoney...')
        api_url = f'https://push2.eastmoney.com/api/qt/stock/get?secid={config["secid"]}&fields=f43,f44,f45,f46,f47,f48,f49,f50,f51,f52,f57,f58,f60,f107,f116,f117,f152,f168,f169,f170,f171,f161,f162,f163,f164,f165,f166,f167'
        headers = {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': 'https://quote.eastmoney.com/'
        }
        
        response = requests.get(api_url, headers=headers, timeout=10)
        data = response.json()
        
        if data.get('rc') == 0 and data.get('data'):
            price_data_raw = data['data']
            price = price_data_raw.get('f43', 0) / 100
            price_change = price_data_raw.get('f169', 0) / 100
            price_change_percent = price_data_raw.get('f170', 0) / 100
            close_prev = price - price_change
            
            print(f'[{datetime.now().strftime("%Y-%m-%d %H:%M:%S")}] {config["name"]} price fetched: ¥{price:.2f} ({price_change:+.2f}, {price_change_percent:+.2f}%)')
            
            price_data = {
                'timestamp': int(time.time() * 1000),
                'price': price,
                'price_change': price_change,
                'price_change_percent': price_change_percent,
                'currency': 'CNY',
                'unit': config['unit'],
                'high': price_data_raw.get('f44', 0) / 100,
                'low': price_data_raw.get('f45', 0) / 100,
                'open': price_data_raw.get('f46', 0) / 100,
                'close_prev': round(close_prev, 2),
                'volume': price_data_raw.get('f49', 0),
                'code': price_data_raw.get('f57', ''),
                'name': config['name']
            }
            
            if metal_type not in price_cache:
                price_cache[metal_type] = []
            price_cache[metal_type].append(price_data)
            if len(price_cache[metal_type]) > MAX_HISTORY:
                price_cache[metal_type].pop(0)
            
            return price_data
        else:
            print(f'[{datetime.now().strftime("%Y-%m-%d %H:%M:%S")}] Invalid response from API for {config["name"]}')
            return get_mock_price(metal_type)
    except Exception as e:
        print(f'[{datetime.now().strftime("%Y-%m-%d %H:%M:%S")}] Error fetching {config["name"]} price: {e}')
        return get_mock_price(metal_type)

def fetch_kline_data(metal_type, klt, days=365):
    config = METALS_CONFIG.get(metal_type)
    if not config:
        return []
    
    try:
        print(f'[{datetime.now().strftime("%Y-%m-%d %H:%M:%S")}] Fetching {config["name"]} kline data (klt={klt})...')
        end_date = datetime.now().strftime('%Y%m%d')
        beg_date = (datetime.now() - timedelta(days=days)).strftime('%Y%m%d')
        
        api_url = f'https://push2his.eastmoney.com/api/qt/stock/kline/get?secid={config["secid"]}&fields1=f1,f2,f3,f4,f5,f6&fields2=f51,f52,f53,f54,f55,f56,f57,f58&klt={klt}&fqt=1&beg={beg_date}&end={end_date}'
        headers = {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': 'https://quote.eastmoney.com/'
        }
        
        response = requests.get(api_url, headers=headers, timeout=15)
        data = response.json()
        
        history = []
        if data.get('rc') == 0 and data.get('data') and data['data'].get('klines'):
            klines = data['data']['klines']
            
            for kline_str in klines:
                parts = kline_str.split(',')
                if len(parts) >= 8:
                    date_str = parts[0]
                    close_price = float(parts[2])
                    
                    try:
                        if klt == 101:
                            date = datetime.strptime(date_str, '%Y-%m-%d')
                        elif klt == 60:
                            date = datetime.strptime(date_str, '%Y-%m-%d %H:%M')
                        else:
                            date = datetime.strptime(date_str, '%Y-%m-%d')
                        
                        price_data = {
                            'timestamp': int(date.timestamp() * 1000),
                            'date': date_str,
                            'price': close_price,
                            'open': float(parts[1]),
                            'high': float(parts[3]),
                            'low': float(parts[4]),
                            'volume': int(parts[5]),
                            'amount': float(parts[6]),
                            'price_change_percent': float(parts[7]),
                            'currency': 'CNY',
                            'unit': config['unit']
                        }
                        
                        history.append(price_data)
                    except Exception as e:
                        print(f'Error parsing kline: {kline_str}, error: {e}')
            
            print(f'[{datetime.now().strftime("%Y-%m-%d %H:%M:%S")}] Fetched {len(history)} kline data points for {config["name"]}')
        
        return history
    except Exception as e:
        print(f'[{datetime.now().strftime("%Y-%m-%d %H:%M:%S")}] Error fetching kline data: {e}')
        return []

def get_mock_price(metal_type):
    config = METALS_CONFIG.get(metal_type)
    base_prices = {'gold': 1035.00, 'silver': 7.5, 'platinum': 220.0, 'palladium': 280.0}
    base_price = base_prices.get(metal_type, 100.0)
    
    variation = random.uniform(-5, 5)
    price = base_price + variation
    price_change = random.uniform(-2, 2)
    price_change_percent = (price_change / base_price) * 100
    
    price_data = {
        'timestamp': int(time.time() * 1000),
        'price': price,
        'price_change': price_change,
        'price_change_percent': price_change_percent,
        'currency': 'CNY',
        'unit': config['unit'],
        'high': price + random.uniform(0, 5),
        'low': price - random.uniform(0, 5),
        'open': base_price,
        'close_prev': base_price,
        'volume': random.randint(100000, 200000),
        'code': config['secid'].split('.')[1],
        'name': config['name']
    }
    
    if metal_type not in price_cache:
        price_cache[metal_type] = []
    price_cache[metal_type].append(price_data)
    if len(price_cache[metal_type]) > MAX_HISTORY:
        price_cache[metal_type].pop(0)
    
    print(f'[{datetime.now().strftime("%Y-%m-%d %H:%M:%S")}] Using mock price for {config["name"]}: ¥{price:.2f}')
    return price_data

def is_trading_time():
    now = datetime.now()
    hour = now.hour
    minute = now.minute
    
    if 9 <= hour < 11 or (hour == 11 and minute <= 30):
        return True
    elif 13 <= hour < 15:
        return True
    elif hour >= 21 or hour < 3:
        return True
    return False

def update_prices_periodically():
    while True:
        if is_trading_time():
            for metal_type in METALS_CONFIG.keys():
                fetch_metal_price(metal_type)
        time.sleep(600)

@app.route('/')
def index():
    return send_from_directory('public', 'index.html')

@app.route('/api/metal-price')
def get_metal_price():
    metal_type = request.args.get('metal', 'gold')
    price_data = fetch_metal_price(metal_type)
    if price_data:
        return jsonify(price_data)
    return jsonify({'error': 'Failed to fetch price'}), 500

@app.route('/api/metal-daily-kline')
def get_metal_daily_kline():
    metal_type = request.args.get('metal', 'gold')
    history = fetch_kline_data(metal_type, klt=101, days=60)
    return jsonify(history)

@app.route('/api/metal-monthly-kline')
def get_metal_monthly_kline():
    metal_type = request.args.get('metal', 'gold')
    history = fetch_kline_data(metal_type, klt=101, days=365)
    return jsonify(history)

@app.route('/api/metal-today-history')
def get_metal_today_history():
    metal_type = request.args.get('metal', 'gold')
    history = fetch_kline_data(metal_type, klt=60, days=1)
    
    if history:
        today = datetime.now().strftime('%Y-%m-%d')
        today_data = [item for item in history if today in item.get('date', '')]
        if today_data:
            return jsonify(today_data)
    
    if metal_type in price_cache:
        return jsonify(price_cache[metal_type])
    
    return jsonify([])

@app.route('/api/gold-price')
def get_gold_price():
    return get_metal_price()

@app.route('/api/gold-history')
def get_gold_history():
    metal_type = 'gold'
    if metal_type in price_cache:
        return jsonify(price_cache[metal_type])
    return jsonify([])

@app.route('/api/gold-yearly-history')
def get_gold_yearly_history():
    return get_metal_monthly_kline()

@app.route('/api/gold-today-history')
def get_gold_today_history():
    return get_metal_today_history()

if __name__ == '__main__':
    print(f'[{datetime.now().strftime("%Y-%m-%d %H:%M:%S")}] Starting Flask application...')
    
    update_thread = threading.Thread(target=update_prices_periodically, daemon=True)
    update_thread.start()
    
    port = int(os.environ.get('PORT', 8000))
    debug_mode = os.environ.get('FLASK_DEBUG', 'false').lower() == 'true'
    print(f'[{datetime.now().strftime("%Y-%m-%d %H:%M:%S")}] Server running on port {port}')
    app.run(host='0.0.0.0', port=port, debug=debug_mode)
