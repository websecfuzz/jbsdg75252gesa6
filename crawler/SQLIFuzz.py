import copy
import logging
import os
import random

import asyncio

from playwright.async_api import async_playwright

from HTTPRequest import convert_request_from_entry
from SQLIRequestCollection import sqli_request_collection
from config import config
from general_functions import send_HTTP_request, check_SQL_output, randomword
from sql_analysis import find_queries_in_time_window, get_param_val_request_entry

logger = config.logger
stats = config.stats
stats['total_req'] = 0
stats['sql_req'] = 0
stats['not_sql_req'] = 0
stats['sql_req_detected'] = 0
stats['sql_req_not_detected'] = 0
stats['error_req'] = 0

def random_weird_char():
    """Return a randomly selected 'weird' character."""
    weird_chars = ['%', '&', '*', '@', '#', '$', '!', '?', '~', '^',
                   '(', ')', '[', ']', '{', '}', '<', '>', '|', '\\',
                   '/', '+', '=', '-', '_', ':', ';', '"', "'", ',',
                   '.', '`', '¢', '£', '¥', '§', '©', '®', '°', '±',
                   'µ', '¶', '·', '÷', '¿', '¬', '½', '¼', '¾', '¹',
                   '²', '³', 'ª', 'º', 'Æ', 'Ø', 'Å', 'æ', 'ø', 'å',
                   'ß', 'Ð', 'Þ', 'ð', 'þ', '×', '¤', '¦', '¨', '¯']

    return random.choice(weird_chars)

def fuzz(req_entry):
    asyncio.run(send_requests(req_entry))

async def send_requests(req_entry):
    page = None
    WUT_URL = os.environ.get('WUT_URL', "http://localhost:8081")

    req = convert_request_from_entry(req_entry)

    async with async_playwright() as p:
        # Create a new API request context
        request_context = await p.request.new_context(
            base_url=WUT_URL,
            extra_http_headers={
                "User-Agent": "Playwright-Async-Client",
                "Accept": "application/json"
            }
        )

        request_result = await check_SQLI(page, req, request_context)

async def check_SQLI(page, req, request_context=None):
    logger.info(f"[SQLiFuzz {req.id[-3:]}] check_SQLI for {req}")
    prepared_target_request = None
    random_char = "'"
    for x in range(50):
        if prepared_target_request:
            chosen_req = random.choice([req, prepared_target_request])
        else:
            chosen_req = req
        prepared_target_request = copy.deepcopy(chosen_req)

        num_params = len(prepared_target_request.paramvals)
        if num_params==0:
            logger.info(f"[SQLiFuzz] check_SQLI is cancelled because num paramvals ==0")
            return False

        chosen_idx = 0
        if num_params>1:
            chosen_idx = random.randint(0,num_params-1)
        logger.info(f"[SQLiFuzz] chosen_idx: {chosen_idx} from {num_params}")

        chosen_pv = prepared_target_request.paramvals[chosen_idx]
        if random_char:
            logger.info(f"[SQLiFuzz] Use ' as the first weird char")

            if prepared_target_request.found_value:
                chosen_pvs = [p for p in prepared_target_request.paramvals if p.value == prepared_target_request.found_value]
                if len(chosen_pvs)>0:
                    ## Prioritize the matched SQL value first
                    chosen_pv = chosen_pvs[0]
                chosen_pv.value = chosen_pv.value+random_char
                random_char = None
            else:
                ## Prioritize the null value first
                null_paramvals = prepared_target_request.get_null_paramvals()
                if len(null_paramvals)>0:
                    chosen_pv = null_paramvals[len(null_paramvals)-1]
                    logger.info(f"[SQLiFuzz] Prioritize to fuzz null value first: {chosen_pv}")
                    chosen_pv.value = chosen_pv.value+randomword(5)+random_char
                else:
                    chosen_pv.value = chosen_pv.value+random_char
                    random_char = None
        else:
            chosen_pv.value = chosen_pv.value+random_weird_char()
        logger.info(f"[SQLiFuzz] Updated results: {chosen_pv}")
        prepared_target_request.update_param_from_paramvals()

        prepared_target_request.update_id()
        prepared_target_request.header["X-FUZZER-COVID"] = prepared_target_request.id
        response = await send_HTTP_request(page, prepared_target_request, request_context)
        if response and response.status>=500:
            logger.info(f"[SQLiFuzz] Server error is detected: {prepared_target_request}")

        if response:
            response_str = await response.text()
        else:
            response_str = ""
        logger.info(f"[SQLiFuzz {req.id[-3:]}] Getting response: %s", response_str[0:400])

        result = check_SQL_output(prepared_target_request, chosen_pv.value)
        if result:
            logger.info(f"[SQLiFuzz] Weird chars is detected: {prepared_target_request} --> {prepared_target_request.SQL_detected}")
            print(f"[SQLiFuzz] Weird chars is detected: {prepared_target_request} --> {prepared_target_request.SQL_detected}")
            if prepared_target_request.SQL_detected and "**ERROR" in prepared_target_request.SQL_detected[0]:
                logger.info(f"[SQLiFuzz] SQL Injection is detected: {prepared_target_request} ==> {prepared_target_request.SQL_detected[0]}")
                print(f"[SQLiFuzz] SQL Injection is detected: {prepared_target_request}")
                sqli_request_collection.add(prepared_target_request)
                sqli_request_collection.save_result()
                stats['sql_req_detected'] += 1
                return prepared_target_request
        else:
            logger.info(f"[SQLiFuzz] No weird chars is detected: {prepared_target_request}")

        if prepared_target_request.error_SQL_detected:
            logger.info(f"[SQLiFuzz] Another SQL Injection is detected: {prepared_target_request} ==> {prepared_target_request.error_SQL_detected}")
            print(f"[SQLiFuzz] Another SQL Injection is detected: {prepared_target_request}")
            sqli_request_collection.add(prepared_target_request)
            sqli_request_collection.save_result()
            stats['sql_req_detected'] += 1
            return prepared_target_request

    logger.info(f"[SQLiFuzz] No SQL Injection. Drop it. {prepared_target_request}")
    stats['sql_req_not_detected'] += 1

def request_analysis(request_entry):
    logger.info(f"[SQLiFuzz {request_entry['sid']}] Check {request_entry['request']['method']} {request_entry['request']['url']} || {request_entry['request']['body']}")
    stats['total_req'] += 1
    matching_queries, error_queries, found_values = find_queries_in_time_window(request_entry['request']['timestamp'], request_entry['response']['timestamp'], get_param_val_request_entry(request_entry), request_entry['sid'])

    if len(matching_queries)>0:
        logger.info(f"[SQLiFuzz {request_entry['sid']}] Get matching queries: {matching_queries} from {request_entry}")
        stats['sql_req'] += 1
        fuzz(request_entry)
    else:
        logger.info(f"[SQLiFuzz {request_entry['sid']}] The request does not trigger SQL query. Drop it.")
        stats['not_sql_req'] += 1
