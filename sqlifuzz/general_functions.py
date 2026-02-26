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

from sql_analysis import find_queries_in_time_window, remove_limit_clause, check_important_param_pairs

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

def get_new_header(request):
    # Prepare headers copy so we can safely adjust Content-Length if body changed
    headers_to_send = dict(request.header) if request.header else {}

    # Compute body bytes for non-multipart to allow Content-Length correction
    body_bytes = None
    if not (request.content_type and str(request.content_type).find("multipart/form-data") > -1):
        if request.post_data_encoded is None:
            body_bytes = b""
        elif isinstance(request.post_data_encoded, bytes):
            body_bytes = request.post_data_encoded
        else:
            try:
                body_bytes = str(request.post_data_encoded).encode('utf-8')
            except Exception:
                body_bytes = None

    # If a content-length header exists but body length changed, update it
    try:
        for hk in list(headers_to_send.keys()):
            if hk.lower() == 'content-length':
                if body_bytes is not None:
                    headers_to_send[hk] = str(len(body_bytes))
                    logger.info(f"[GENERALFUNCTION {request.id[-3:]}] Adjusted Content-Length to %s", headers_to_send[hk])
                else:
                    # remove content-length when we cannot determine body length reliably
                    headers_to_send.pop(hk, None)
                    logger.info(f"[GENERALFUNCTION {request.id[-3:]}] Removed Content-Length header because body length is unknown")
    except Exception:
        pass

    # Normalize Origin and Referer to match the request host to avoid server-side mismatches
    try:
        parsed_req = urlparse(request.full_url if getattr(request, 'full_url', None) else request.url)
        origin_base = f"{parsed_req.scheme}://{parsed_req.netloc}"

        # Ensure Host header exists and matches parsed netloc
        host_keys = [k for k in headers_to_send.keys() if k.lower() == 'host']
        if not host_keys:
            headers_to_send['Host'] = parsed_req.netloc

        for hk in list(headers_to_send.keys()):
            if hk.lower() == 'origin':
                headers_to_send[hk] = origin_base
                logger.info(f"[GENERALFUNCTION {getattr(request,'id','')[-3:]}] Adjusted Origin to %s", origin_base)
            if hk.lower() == 'referer':
                # Try to preserve referer path if present, but ensure host is replaced with origin_base
                try:
                    parsed_ref = urlparse(headers_to_send.get(hk, ''))
                    ref_path = parsed_ref.path or parsed_req.path or '/'
                    new_ref = origin_base + ref_path
                    # include query and fragment if present in original referer
                    if parsed_ref.query:
                        new_ref += '?' + parsed_ref.query
                    if parsed_ref.fragment:
                        new_ref += '#' + parsed_ref.fragment
                    headers_to_send[hk] = new_ref
                except Exception:
                    headers_to_send[hk] = origin_base
                logger.info(f"[GENERALFUNCTION {getattr(request,'id','')[-3:]}] Adjusted Referer to %s", headers_to_send[hk])
    except Exception:
        pass

    return headers_to_send

def normalize_url_for_post(url):
    """Add trailing slash to directory URLs to prevent redirects."""
    # Parse URL to handle query parameters separately
    try:
        parsed = urlparse(url)
        path = parsed.path
        
        # If path doesn't end with / or a file extension, add /
        if path and not path.endswith('/') and not path.split('/')[-1].count('.'):
            path = path + '/'
            # Rebuild URL with normalized path
            return urlunparse((parsed.scheme, parsed.netloc, path, parsed.params, parsed.query, parsed.fragment))
    except Exception:
        pass
    
    return url

def save_request_to_yaml(request, headers_to_send, name="000"):
    WUT_NAME = os.environ.get('WUT_NAME', None)
    directory = f"saved_requests/{WUT_NAME}/"
    os.makedirs(directory, exist_ok=True)
    filename = os.path.join(directory, name + ".yaml")
    try:
        request_data = {
            'full_url': request.full_url,
            'method': request.method,
            'header_to_send': headers_to_send,
            'post_data_encoded': request.post_data_encoded,
            'body_param_dict': request.body_param_dict,
            'content_type': request.content_type,
            'timing': request.timing
        }
        with open(filename, 'w') as f:
            yaml.dump(request_data, f)
        logger.info(f"[GENERALFUNCTION {getattr(request,'id','')[-3:]}] Saved request to {filename}")
    except Exception as e:
        logger.error(f"[GENERALFUNCTION {getattr(request,'id','')[-3:]}] Failed to save request to YAML: {e}")

def load_request_from_yaml_directory(directory):
    requests = []
    try:
        for filename in os.listdir(directory):
            if filename.endswith('.yaml') or filename.endswith('.yml'):
                with open(os.path.join(directory, filename), 'r') as f:
                    request_data = yaml.safe_load(f)
                    requests.append(request_data)
        logger.info(f"[GENERALFUNCTION] Loaded {len(requests)} requests from {directory}")
    except Exception as e:
        logger.error(f"[GENERALFUNCTION] Failed to load requests from YAML directory: {e}")
    return requests

async def send_HTTP_request(page, request, request_context=None):
    request.full_url = f"{request.url}"
    if request.param_encoded:
        request.full_url = f"{request.url}?{request.param_encoded}"

    request.full_url = normalize_url_for_post(request.full_url)

    logger.info(f"[GENERALFUNCTION {request.id[-3:]}] ---SENDING THE REQUEST [{request.id}] TO : [{request.method}] %s", request.full_url)
    logger.info(f"[GENERALFUNCTION {request.id[-3:]}] Post data encoded: {request.post_data_encoded}")

    if request_context:
        api_request_context = request_context
    else:
        api_request_context = page.request

    headers_to_send = get_new_header(request)

    try:
        start_calculation = None
        # Debug: log outgoing request details to help track replay differences
        try:
            logger.info(f"[GENERALFUNCTION {request.id[-3:]}] DEBUG OUTGOING request.full_url: %s", request.full_url)
            logger.info(f"[GENERALFUNCTION {request.id[-3:]}] DEBUG OUTGOING headers: %s", headers_to_send)
            logger.info(f"[GENERALFUNCTION {request.id[-3:]}] DEBUG OUTGOING post_data_encoded (truncated): %s", str(request.post_data_encoded)[:1000])
            if hasattr(request, 'body_param_dict') and request.body_param_dict:
                logger.info(f"[GENERALFUNCTION {request.id[-3:]}] DEBUG OUTGOING body_param_dict: %s", str(request.body_param_dict))
        except Exception:
            pass

        if request.content_type and str(request.content_type).find("multipart/form-data")>-1:
            headers_to_send = copy_dict_excluding_key(headers_to_send,"content-type")
            logger.info(f"[GENERALFUNCTION {request.id[-3:]}] Send using multipart/form-data type")
            logger.info(f"[GENERALFUNCTION {request.id[-3:]}] New header: {str(headers_to_send)}")
            start_calculation = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S,%f")
            response = await api_request_context.fetch(url_or_request=request.full_url,
                                                        method=request.method,
                                                        headers=headers_to_send,
                                                        multipart=request.body_param_dict)
        else:
            start_calculation = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S,%f")
            response = await api_request_context.fetch(url_or_request=request.full_url,
                                                            method=request.method,
                                                            headers=headers_to_send,
                                                            data=request.post_data_encoded)


        end_calculation = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S,%f")
        
        if request.timing==None:
            request.timing = dict()
        request.timing["start_calculation"] = start_calculation
        request.timing["end_calculation"] = end_calculation
        request.timing["calculation_duration"] = (datetime.strptime(end_calculation, "%Y-%m-%d %H:%M:%S,%f") - datetime.strptime(start_calculation, "%Y-%m-%d %H:%M:%S,%f")).total_seconds()

        config.stats['fuzzed_req'] += 1
        config.stats['processing_time_total'] += request.timing["calculation_duration"]
        config.stats['processing_time_ave'] = config.stats['processing_time_total'] / config.stats['fuzzed_req']


        if config.is_save_request:
            save_request_to_yaml(request, headers_to_send, name=str(config.stats['fuzzed_req']))

        # Update activity time for idle shutdown monitor
        try:
            import shared_state
            import time
            shared_state.last_activity_time = time.time()
        except Exception:
            pass

        return response
    except Exception as e:
        logger.info(f"[GENERALFUNCTION {request.id[-3:]}] Web server is error!: %s", str(e)[:2000])
        return None

async def screenshot_response_html(response_str, filename):
    """
    Render `response_str` in a headless browser and save a screenshot to `filename`.
    Returns the filename on success, or None on error.
    """
    try:
        # Ensure directory exists
        dirname = os.path.dirname(filename) or '.'
        os.makedirs(dirname, exist_ok=True)

        # Import async API locally to avoid changing sync imports
        from playwright.async_api import async_playwright

        playwright = await async_playwright().start()
        try:
            browser = await playwright.chromium.launch()
            page = await browser.new_page()
            try:
                # Try to render as HTML; on failure, display as preformatted text
                try:
                    await page.set_content(response_str, wait_until='load')
                except Exception:
                    await page.set_content(f"<pre>{response_str}</pre>")

                await page.screenshot(path=filename, full_page=True)
                return filename
            finally:
                try:
                    await browser.close()
                except Exception:
                    pass
        finally:
            try:
                await playwright.stop()
            except Exception:
                pass
    except Exception as e:
        logger.error(f"[GENERALFUNCTION] Failed to screenshot response: %s", e)
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

def is_sql_syntax_error(SQL_response):
    # Check if the SQL response contains both syntax and error words
    error_indicators = ["syntax", "error"]
    another_indicators = ["near", "error"]
    if all(indicator in SQL_response.lower() for indicator in error_indicators):
        return True
    if all(indicator in SQL_response.lower() for indicator in another_indicators):
        return True
    return False

def is_sql_syntax_error_lists(prepared_target_request):
    SQL_responses = prepared_target_request.SQL_detected
    for SQL_response in SQL_responses:
        if is_sql_syntax_error(SQL_response):
            prepared_target_request.SQL_injection_proof = SQL_response
            return True
    return False

def combining_matching_and_error_queries(matching_queries, error_queries):
    if len(error_queries)>0 and len(matching_queries)>0:
        logger.info(f"[GENERALFUNC] Combining matching and error queries") 
        combined_queries = set(error_queries)
        port = error_queries[0]['port']
        for eq in matching_queries:
            if eq['port']==port:
                logger.info(f"[GENERALFUNC] Including {eq['sql']} to combined queries for port {port}.") 
                combined_queries.add(eq)

        return list(combined_queries)
    return None

def check_SQL_output(request, looked_value=None):
    pairs = {}
    if looked_value:
        pairs['looked_value'] = looked_value
    else:
        pairs.update(dict(request.header))
        pairs.update({pv.param: pv.value for pv in request.paramvals})

    if request.timing is None:
        # Handle the missing timing gracefully
        logger.info(f"[GENERALFUNC {request.id[-3:]}] Error: request.timing is None")
        return None, None, None  # or some appropriate default

    ## find any SQL queries that contain any of the parameter pairs. If the response contains any SQL errors, we also capture those even though they may not contain the parameter values.
    # matching_queries, found_values = find_queries_in_time_window(request.timing["start_calculation"], request.timing["end_calculation"], pairs)
    matching_queries, error_queries, found_value, combination_logs = find_queries_in_time_window(request.timing["start_calculation"], request.timing["end_calculation"], pairs, request.id[-3:], only_find_error=True, check_malformed=True)

    if len(error_queries)>0:
        logger.info(f"[GENERALFUNC {request.id[-3:]}] Found Error Query: {error_queries} from {request}")
        request.error_SQL_detected = error_queries

    request.SQL_injection_detected = False
    if combination_logs:
        combination_str = create_combined_SQL_string(combination_logs)
        request.SQL_injection_detected = True
        request.SQL_injection_proof = combination_str

    ## Only return TRUE if queries contain the parameter pairs regardless of SQL errors
    request.SQL_detected = matching_queries
    if len(matching_queries)>0:
        logger.info(f"[GENERALFUNC {request.id[-3:]}] found_value: {found_value}")
        request.matched_payload = found_value
        return True
    else:
        return False

def create_combined_SQL_string(combination_logs):
    ## create combination string, which only contains the sql part of the combination logs.
    ## if the string is the same as the other string, then we only keep one of them.
    string_set = set()
    for log in combination_logs:
        string_set.add(log['sql'])

    return " | ".join(string_set)


def check_SQL_response(request, looked_value=None):
    pairs = {}
    if looked_value:
        pairs['looked_value'] = looked_value
    else:
        pairs.update(dict(request.header))
        pairs.update({pv.param: pv.value for pv in request.paramvals})

    if request.timing is None:
        # Handle the missing timing gracefully
        logger.info(f"[GENERALFUNC {request.id[-3:]}] Error: request.timing is None")
        return None, None, None  # or some appropriate default

    ## find any SQL queries that contain any of the parameter pairs. If the response contains any SQL errors, we also capture those even though they may not contain the parameter values.
    matching_queries, error_queries, found_value = find_queries_in_time_window(request.timing["start_calculation"], request.timing["end_calculation"], pairs, request.id[-3:], only_find_error=True)

    if len(error_queries)>0:
        logger.info(f"[GENERALFUNC {request.id[-3:]}] Found Error Query: {error_queries} from {request}")
        request.error_SQL_detected = error_queries

    ## Only return TRUE if queries contain the parameter pairs regardless of SQL errors
    request.SQL_detected = matching_queries
    if len(matching_queries)>0:
        logger.info(f"[GENERALFUNC {request.id[-3:]}] found_value: {found_value}")
        request.matched_payload = found_value
        return True
    else:
        return False