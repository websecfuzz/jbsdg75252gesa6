import argparse
import ctypes  # An included library with Python install.
import re
import traceback
from typing import List
from sys import platform
from datetime import datetime
from urllib.parse import urlparse, parse_qs
from urllib.parse import unquote
import os

from Dictionary import dictionary
from param_value import ParamValue, ParamValuePosition
from config import Config, config
from pathlib import Path

def delete_folder_files(dir):
    path = Path(dir)
    path_parent = path.parent.absolute()

    for folder in os.listdir(path_parent):
        folder_path = os.path.join(path_parent, folder)

        if os.path.isdir(folder_path):
            delete_files(folder_path)

def delete_files(dir):
    print(f"[FUNCTION] Deleting files in {dir}")
    try:
        os.system(f"find {dir} -amin +5 -type f -delete")
    except Exception as e:
        print(f"[FUNCTION] Error in delete_files: {dir}")
        print(f"[FUNCTION] {e}")
        print(f"[FUNCTION] {traceback.format_exc()[:1000]}")

def escape_sql_value(value):
    if value == '':
        return "''"
    elif value.isdigit():
        return value
    elif value.lower() in ('null',):
        return 'NULL'
    else:
        # Escape single quotes in string values
        value = value.replace("'", "''")
        return f"'{value}'"

def fix_prepared_query(raw_input):
    # Split into query and parameters
    if '|' not in raw_input:
        print("[FUNCTION] The prepared query does not contain a '|' separator between query and parameters. Cancel the process.")
        print(f"[FUNCTION]", raw_input)
        return raw_input

    query_part, *params = map(str.strip, raw_input.strip().split('|'))
    query_clean = re.sub(r'\s+', ' ', query_part.strip())

    # Replace ? with each parameter
    fixed_query = ''
    param_index = 0

    for token in re.split(r'(\?)', query_clean):
        if token == '?':
            if param_index >= len(params):
                print(f"[FUNCTION] More placeholders than parameters. Cancel the process.")
                print(f"[FUNCTION]", raw_input)
                return raw_input
            fixed_query += escape_sql_value(params[param_index])
            param_index += 1
        else:
            fixed_query += token

    return fixed_query

def escape_sql_value2(value):
    if value == '':
        return "''"
    elif re.fullmatch(r'\d+(\.\d+)?', value):  # Integer or float
        return value
    elif value.lower() == 'null':
        return 'NULL'
    else:
        # Escape single quotes in string values
        value = value.replace("'", "''")
        return f"'{value}'"

def fix_named_prepared_query(raw_input):
    if '|' not in raw_input:
        print("[FUNCTION] The prepared query does not contain a '|' separator between query and parameters. Cancel the process.")
        print(f"[FUNCTION]", raw_input)
        return raw_input

    # Split query and parameters
    query_part, *bindings = map(str.strip, raw_input.strip().split('|'))

    # Parse all bindings into a dictionary
    param_dict = {}
    for binding in bindings:
        match = re.match(r'^:?(?P<key>\w+)\s*=>\s*(?P<value>.*)$', binding)
        if match:
            key = match.group('key')
            value = match.group('value')
            param_dict[key] = escape_sql_value2(value)
        else:
            print(f"[FUNCTION] Invalid binding format: {binding}. Cancel the process.")
            print(f"[FUNCTION]", raw_input)
            return raw_input

    # Replace named placeholders
    def replacer(match):
        key = match.group(1)
        if key not in param_dict:
            print(f"[FUNCTION] No value provided for parameter :{key}. Return empty value.")
            print(f"[FUNCTION]", raw_input)
            return ""
        return param_dict[key]

    fixed_query = re.sub(r':(\w+)', replacer, query_part)

    return fixed_query

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

def get_state_path(state_name):
    # return f"../login_state/{state_name}.json"
    return f"../login_state/{config.data['PROJECT_NAME']}/{state_name}.json"

def show_popup_message(message, title="Information"):
    ctypes.windll.user32.MessageBoxW(0, message, title, 0)


async def manual_login(playwright, user, login_url):
    """
    Save user credential in a JSON file for being used by other functions
    :param playwright:
    :return:
    """
    browser = await playwright.chromium.launch(headless=False)
    context = await browser.new_context()
    page = await context.new_page()

    await page.goto(login_url)
    await page.wait_for_load_state()

    if (user!="Anonymous"):
        print(f"Login with {user} credential")
        if platform == "win32":
            show_popup_message(f"Login with {user} credential")
        await page.pause()

    json_path = get_state_path(user)
    await page.context.storage_state(path=json_path)
    homepage = page.url

    await context.close()
    await browser.close()

    return json_path, homepage

def manual_login_sync(playwright, user, login_url):
    """
    Save user credential in a JSON file for being used by other functions
    :param playwright:
    :return:
    """
    browser = playwright.chromium.launch(headless=False)
    context = browser.new_context()
    page = context.new_page()

    page.goto(login_url)
    page.wait_for_load_state()
    show_popup_message(f"Login with {user} credential")
    page.pause()

    json_path = get_state_path(user)
    page.context.storage_state(path=json_path)

    context.close()
    browser.close()

    return json_path

def exclude_certain_index(data_list, idx_to_exclude):
    return [x for i,x in enumerate(data_list) if i!=idx_to_exclude]

async def get_form_id(form):
    form_name = ""
    id = await form.get_attribute("id")
    if id:
        form_name += id
    name = await form.get_attribute("name")
    if name:
        form_name += name
    action = await form.get_attribute("action")
    if action:
        form_name += action
    return form_name

def get_disjuction(higher_role_corpus, lower_role_corpus):
    return [req for req in higher_role_corpus if req not in lower_role_corpus]

def cleanhtml(raw_html):
    CLEANR = re.compile('<.*?>')
    cleantext = re.sub(CLEANR, '', raw_html)
    return cleantext

def split_key_val(txt):
    pos = txt.find('=')
    if pos>-1:
        key = txt[:pos]
        val = txt[pos+1:]
    else:
        key = txt
        val = None
    return key, val


def parse_post_data(post_data):
    # Parse the data into a dictionary
    ## For example: "subject=etcigzap&notestitle=xyomgzap&notesdesc=qskuyzap&submit="
    print(f"[FUNCTION] Call parse_post_data for {post_data}")
    parsed = parse_qs(post_data, keep_blank_values=True)
    # Simplify values: turn single-item lists into strings
    return {k: v[0] if len(v) == 1 else v for k, v in parsed.items()}

def get_stdr_url_from_page(full_url):
    parsed_url = urlparse(full_url)
    url = f"{parsed_url.scheme}://{parsed_url.netloc}{parsed_url.path}"
    return url

def get_query_keys(url):
    # Parse the URL
    parsed_url = urlparse(url)
    # query_keys = list(parse_qs(parsed_url.query).keys())
    ## Anticipate if there is URL query using different separator, like those in SMF
    ## http://localhost:8084/index.php?action=movetopic;current_board=1;topic=1.0
    normalized_query = parsed_url.query.replace(';', '&')
    query_keys = sorted(parse_qs(normalized_query).keys())
    return query_keys

def convert_to_dict(param_encoded):
    paramvals = dict()
    if param_encoded.find('&')>-1:
        for txt in param_encoded.split('&'):
            key, val = split_key_val(txt)
            paramvals[key] = val
    else:
        key, val = split_key_val(param_encoded)
        paramvals[key] = val
    return paramvals

def time_diff(later_time, first_time):
    difference = later_time - first_time
    duration_in_s = difference.total_seconds()
    days    = divmod(duration_in_s, 86400)        # Get days (without [0]!)
    hours   = divmod(days[1], 3600)               # Use remainder of days to calc hours
    minutes = divmod(hours[1], 60)                # Use remainder of hours to calc minutes
    seconds = divmod(minutes[1], 1)

    return days,int(hours[0]),int(minutes[0]),int(seconds[0])

def get_detected_time(inp):
    if inp.detected_time:
        return inp.detected_time
    return datetime.now()

def is_CRUD(query):
    if query.find("INSERT")>-1 or query.find("UPDATE")>-1 or query.find("DELETE")>-1:
        return True
    return False

def is_contain_words(query, desired_words):
    for desired_word in desired_words:
        if str(query).lower().find(str(desired_word).lower())>-1:
            return True
    return False

def is_same_param_field(param_encoded1, param_encoded2):
    pv1 = convert_to_dict(param_encoded1)
    pv2 = convert_to_dict(param_encoded2)

    ## Convert to set to get the keys of a dict, and compare without checking the order
    return set(pv1) == set(pv2)

def change_port_url(url,new_port):
    aaa = urlparse(url)
    return aaa._replace(netloc=aaa.netloc.replace(str(aaa.port), new_port)).geturl()

def save_param_value_to_dict(param_name, param_val, role):
    if param_name and param_val:
        print(f"[FUNCTION {role}] Saving {param_name}: {param_val} to dict")
        pv1 = ParamValue(param_name,param_val,ParamValuePosition.FORM)
        pv1.role = role
        dictionary.add(pv1)
        return pv1
    else:
        print(f"[FUNCTION {role}] Cannot Saving {param_name}: {param_val} because it is NONE")

def extract_paramvals_from_url(full_url, role, is_saved_to_dict=True):
    parsed_url = urlparse(full_url)
    url = f"{parsed_url.scheme}://{parsed_url.netloc}{parsed_url.path}"
    param_encoded = parsed_url.query
    paramvals = list()
    if param_encoded:
        if param_encoded.find('&')>-1:
            for txt in param_encoded.split('&'):
                key, val = split_key_val(txt)
                # key, val = self.split_key_val(txt)
                pv1 = ParamValue(key,val,ParamValuePosition.URL)
                pv1.role = role
                paramvals.append(pv1)
                if is_saved_to_dict:
                    dictionary.add(pv1)
        elif param_encoded.find(';')>-1:
            for txt in param_encoded.split(';'):
                key, val = split_key_val(txt)
                pv1 = ParamValue(key,val,ParamValuePosition.URL)
                pv1.role = role
                paramvals.append(pv1)
                if is_saved_to_dict:
                    dictionary.add(pv1)
        else:
            key, val = split_key_val(param_encoded)
            # key, val = self.split_key_val(self.param_encoded)
            pv2 = ParamValue(key,val,ParamValuePosition.URL)
            pv2.role = role
            paramvals.append(pv2)
            if is_saved_to_dict:
                dictionary.add(pv2)

    return paramvals

def compare_request(req1, req2):
    print("[FUNCTION] COMPARING ", req1, req2)
    if len(req1.paramvals)>0 or len(req2.paramvals)>0:
        print("[FUNCTION] COMPARING the paramvals")
        return req1.url == req2.url and req1.method == req2.method and req1.paramvals == req2.paramvals
    return req1.url == req2.url and req1.method == req2.method and req1.post_data_encoded == req2.post_data_encoded


def clean_url_param(value):
    return unquote(value)

def combine_url(original_url, user_input_url):
    from urllib.parse import urlparse, urlunparse

    # original_url = "http://localhost:4567/login"
    # user_input_url = "http://localhost:8888"

    # Parse both URLs
    parsed_original = urlparse(original_url)
    parsed_user_input = urlparse(user_input_url)

    # Use scheme and netloc (host:port) from user input, path from original
    new_url = urlunparse((
        parsed_user_input.scheme,
        parsed_user_input.netloc,
        parsed_original.path,
        parsed_original.params,
        parsed_original.query,
        parsed_original.fragment
    ))

    print(f"New URL: {new_url}")
    return new_url

def retrieve_arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", nargs='?', help="Config file name", type=str)
    parser.add_argument("--hour", nargs='?', help="The number of hours for the fuzzing campaign", type=int)
    parser.add_argument("--minute", nargs='?', help="The number of minutes for the fuzzing campaign.", type=int)
    parser.add_argument("--url", nargs='?', help="Homepage URL", type=str)
    parser.add_argument("--name", nargs='?', help="Project Name", type=str)
    parser.add_argument("--ignored-sql", nargs='+', help="DB Table(s) that should be ignored")
    parser.add_argument("--roles", nargs='+', help="User Roles")
    parser.add_argument("--only-crawling", nargs='?', help="Only Running the Crawling Module", type=str)
    parser.add_argument("--only-driver", nargs='?', help="Only Running the Driver Module", type=str)
    parser.add_argument("--only-checker", nargs='?', help="Only Running the Checker Module", type=str)
    parser.add_argument("--without-login", nargs='?', help="Only Using Saved Cookies", type=str)
    parser.add_argument("--proxy", nargs='?', help="Only to use a proxy server", type=str)
    return parser.parse_args()