# from active_checker import HOMEPAGE_URL, URL
import json
import os
import string
import random
import urllib
import re
from datetime import datetime

from urllib.parse import urlparse, urlunparse, parse_qs
import yaml

from playwright.sync_api import Request

import utils
from sql_analysis import find_queries_in_time_window, remove_limit_clause, check_important_param_pairs
from utils import fuzz_open

from config import config

## TYPE-ALIAS
URL = str ## For example, http://localhost/wordpress/admin.php
logger = config.logger

def load_config(config_path='config.yaml'):
    with open(config_path, encoding="utf-8_sig") as f:
        data = yaml.load(f, Loader=yaml.FullLoader)

    print('Config loaded.')  # Just to show that it only loads once.
    return data

def is_token_key(key):
    # Heuristics: keys that are long random hex or base32/64-like
    try:
        return bool(re.fullmatch(r'[a-fA-F0-9]{8,}', key)) or bool(re.fullmatch(r'[a-zA-Z0-9]{10,}', key))
    except Exception as e:
        print(f"[GENERALFUNCTION] Failed in is_token_key: {e}")
    return False

def is_token_value(value):
    # Heuristics: values that are long and look like hashes or non-dictionary words
    try:
        return bool(re.fullmatch(r'[a-fA-F0-9]{10,}', value)) or bool(re.fullmatch(r'[a-zA-Z0-9+/=]{20,}', value))
    except Exception as e:
        print(f"[GENERALFUNCTION] Failed in is_token_value: {e}")
    return False

def identify_security_params(url):
    parsed_url = urlparse(url)
    normalized_query = parsed_url.query.replace(';', '&')
    params = parse_qs(normalized_query)

    tokens = {}
    for key, values in params.items():
        key_flag = is_token_key(key)
        value_flag = any(is_token_value(v) for v in values)
        if key_flag or value_flag:
            tokens[key] = values
            # print(f"[FUNCTION] Getting token value: {values}")
    return tokens

def filterbyvalue(seq, value):
    for el in seq:
        if el.attribute==value:
            yield el

def clean_base_url(base_url):
    """Keeps only the scheme and netloc (domain) of the base URL."""
    parsed = urlparse(base_url)
    cleaned = parsed._replace(path='', params='', query='', fragment='')
    return urlunparse(cleaned)

def is_same_domain(url: URL):
    base_url = clean_base_url(config.data["HOMEPAGE_URL"])

    if (url.find(base_url)>-1):
        return True

    if (url.find("http://")>-1 or url.find("https://")>-1):
        return False
    else:
        return True

def get_full_link(url):
    """
    to ensure that the given url is written in complete url. Some crawled links may only put incomplete url like 'new.php'
    :param url:
    :return:
    """
    if (url.find(config.data["HOMEPAGE_URL"])==0):
        return url

    if (url.find("http://")==0 or url.find("https://")==0):
        return url
    else:
        if url.find("/")==0:
            parsed_url = urlparse(config.data["HOMEPAGE_URL"])
            return f"{parsed_url.scheme}://{parsed_url.netloc}{url}"
        else:
            if config.data["HOMEPAGE_URL"][-1:]=="/":
                return config.data["HOMEPAGE_URL"]+url
            else:
                return config.data["HOMEPAGE_URL"]+"/"+url

def get_absolute_link(url, current_page_url):
    return str(urllib.parse.urljoin(current_page_url,url))

def get_complete_link(url, current_page_url):
    """
    to ensure that the given url is written in complete url. Some crawled links may only put incomplete url like 'new.php'
    :param url:
    :return:
    """
    if (url.find(config.data["HOMEPAGE_URL"])==0):
        return url

    if (url.find("http://")==0 or url.find("https://")==0):
        return url
    else:
        if url.find("/")==0:
            parsed_url = urlparse(config.data["HOMEPAGE_URL"])
            return f"{parsed_url.scheme}://{parsed_url.netloc}{url}"
        else:
            if config.data["HOMEPAGE_URL"][-1:]=="/":
                return current_page_url+url
            else:
                return current_page_url+"/"+url

def print_request(request: Request):
    if request.method=="POST":
        print(">> a Post Request is detected", request, request.headers, request.post_data_json)

def randomword(length):
    letters = string.ascii_lowercase
    return ''.join(random.choice(letters) for i in range(length))

def save_credentials(playwright, user, path):
    """
    Save user credential in a JSON file for being used by other functions
    :param playwright:
    :return:
    """
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()

    page.goto(config.data["HOMEPAGE_URL"])
    page.get_by_label("Username or Email Address").fill(user['username'])
    page.get_by_label("Password", exact=True).fill(user['password'])
    page.get_by_role("button", name="Log In").click()
    page.wait_for_load_state()

    page.context.storage_state(path=path)

    context.close()
    browser.close()

def manually_save_credentials(playwright, path):
    """
    Save user credential in a JSON file for being used by other functions
    :param playwright:
    :return:
    """
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()

    page.goto(config.data["HOMEPAGE_URL"])
    page.wait_for_load_state()

    page.pause()

    page.context.storage_state(path=path)

    context.close()
    browser.close()

def read_cov_from_file(coverage_file_path):
    if not os.path.exists(coverage_file_path):
        print("[GENERALFUNCTION] Path does not exist: ",coverage_file_path)
        return 0,0

    with fuzz_open(coverage_file_path, "r", isCompress=True) as f:
        try:
            coverage_report = json.load(f)
        except Exception as e:
            coverage_report = None
            print(f"[GENERALFUNCTION] {e}")

    if not coverage_report:
        print("[GENERALFUNCTION] Error in Loading the cov file")
        return 0,0

    hit_paths = utils.extract_hit_paths(coverage_report)
    stringified_hit_paths = set(utils.stringify_hit_paths(hit_paths))
    utils.all_lines_count_dict(hit_paths, config.line_coverage)
    hit_path_set = set(stringified_hit_paths)
    print(f"[GENERALFUNCTION] Found {len(hit_path_set)} of hit_path_set")

    return hit_path_set, stringified_hit_paths


import re

def extract_sql_command_and_table(query):
    # Normalize query to ignore case and remove extra whitespace
    normalized = ' '.join(query.strip().split()).lower()

    patterns = {
        'insert': r'insert\s+into\s+`?(\w+)`?',
        'update': r'update\s+`?(\w+)`?',
        'delete': r'delete\s+from\s+`?(\w+)`?'
    }

    for command, pattern in patterns.items():
        match = re.search(pattern, normalized, re.IGNORECASE)
        if match:
            return command.upper(), match.group(1)

    return None, None


def extract_all_pairs(request: Request):
    """
    Extracts all name=value pairs from HTTP headers, URL query string,
    and HTTP body into a single dictionary. Later sources overwrite earlier ones.
    
    Priority: headers → query → body
    
    Parameters:
        request (playwright.sync_api.Request): The intercepted HTTP request object.
    
    Returns:
        dict: All extracted name-value pairs combined.
    """
    pairs = {}

    # 1. Headers
    try:
        pairs.update(dict(request.headers))
    except Exception as e:
        print(f"[GENERALFUNCTION] Error in extract_all_pairs: {e}")
        pass

    # 2. Query string
    try:
        parsed_url = urlparse(request.url)
        query_params = parse_qs(parsed_url.query)
        # Flatten lists if single value
        pairs.update({k: v[-1] if isinstance(v, list) else v for k, v in query_params.items()})
    except Exception as e:
        print(f"[GENERALFUNCTION] Error in extract_all_pairs: {e}")
        pass

    # 3. Body
    try:
        post_data = request.post_data
        if post_data:
            content_type = request.headers.get("content-type", "")
            if "application/json" in content_type:
                try:
                    json_data = json.loads(post_data)
                    if isinstance(json_data, dict):
                        pairs.update(json_data)
                except Exception as e:
                    print(f"[GENERALFUNCTION] Error in extract_all_pairs: {e}")
                    pass
            elif "application/x-www-form-urlencoded" in content_type:
                form_params = parse_qs(post_data)
                pairs.update({k: v[-1] if isinstance(v, list) else v for k, v in form_params.items()})
            else:
                # Could try to parse multipart/form-data here if needed
                pass
    except Exception as e:
        print(f"[GENERALFUNCTION] Error in extract_all_pairs: {e}")
        pass

    return pairs

async def send_HTTP_request(page, request, request_context=None):
    request.full_url = f"{request.url}"
    if request.param_encoded:
        request.full_url = f"{request.url}?{request.param_encoded}"

    logger.info(f"[GENERALFUNCTION] ---SENDING THE REQUEST [{request.id}] TO : [{request.method}] %s", request.full_url)
    logger.info(f"[GENERALFUNCTION] Post data encoded: {request.post_data_encoded}")

    if request_context:
        api_request_context = request_context
    else:
        api_request_context = page.request

    try:
        start_calculation = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S,%f")
        if request.content_type and str(request.content_type).find("multipart/form-data")>-1:
            new_header = copy_dict_excluding_key(request.header,"content-type")
            logger.info(f"[GENERALFUNCTION] Send using multipart/form-data type")
            logger.info(f"[GENERALFUNCTION] New header: {str(new_header)}")
            response = await api_request_context.fetch(url_or_request=request.full_url,
                                                        method=request.method,
                                                        headers=new_header,
                                                        multipart=request.body_param_dict)
        else:
            response = await api_request_context.fetch(url_or_request=request.full_url,
                                                        method=request.method,
                                                        headers=request.header,
                                                        data=request.post_data_encoded)
        end_calculation = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S,%f")
        # logger.info(f"[GENERALFUNCTION] Response: {response} from request ID: %s",request.id)
        
        if request.timing==None:
            request.timing = dict()
        request.timing["start_calculation"] = start_calculation
        request.timing["end_calculation"] = end_calculation

        return response
    except Exception as e:
        logger.info(f"[GENERALFUNCTION] Web server is error!: %s", str(e)[:2000])
        return None

def copy_dict_excluding_key(original_dict, key_to_exclude):
    """
    Returns a copy of original_dict excluding the specified key_to_exclude.
    Raises a KeyError if key_to_exclude is not found in the dictionary.

    :param original_dict: dict - The dictionary to copy.
    :param key_to_exclude: any - The key to exclude from the copy.
    :return: dict - A new dictionary without the excluded key.
    """
    if key_to_exclude not in original_dict:
        print(f"[FUNCTION] Key '{key_to_exclude}' not found in the dictionary.")
        return original_dict

    return {k: v for k, v in original_dict.items() if k != key_to_exclude}

def check_value_in_query(query_logs,param_pairs):
    sorted_logs = list()
    found_value = None
    new_pairs = check_important_param_pairs(param_pairs)
    for log in query_logs:
        for key, val in new_pairs.items():
            if val==None or val=="":
                continue

            query = remove_limit_clause(log.lower())
            query_array = re.split(r'[,\s;]+', query)

            if len(query_array)>0:
                if str(val).lower() in query_array:
                    sorted_logs.append(log)
                    logger.info(f"[SQLAnalysis {id}] Getting {key}==>{val} in %s", log)
                    found_value = val
                    break
    return sorted_logs, found_value

def check_SQL_output(request, looked_value=None):
    pairs = {}
    if looked_value:
        pairs['looked_value'] = looked_value
    else:
        pairs.update(dict(request.header))
        pairs.update({pv.param: pv.value for pv in request.paramvals})

    if request.timing is None:
        # Handle the missing timing gracefully
        print("Error: request.timing is None")
        return None, None, None  # or some appropriate default

    # matching_queries, found_values = find_queries_in_time_window(request.timing["start_calculation"], request.timing["end_calculation"], pairs)
    matching_queries, error_queries, found_values = find_queries_in_time_window(request.timing["start_calculation"], request.timing["end_calculation"], pairs, request.id[-3:], only_find_error=True)

    if len(error_queries)>0:
        logger.info(f"[GENERALFUNC] Found Error Query: {error_queries} from {request}")
        request.error_SQL_detected = error_queries

    request.SQL_detected = matching_queries
    if len(matching_queries)>0:
        logger.info(f"[GENERALFUNC] found_values: {found_values}")
        return True
    else:
        return False