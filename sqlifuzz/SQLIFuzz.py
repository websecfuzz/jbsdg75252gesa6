import copy
import logging
import os
import random

import asyncio

from playwright.async_api import async_playwright
from requests import request

from HTTPRequest import convert_request_from_entry
from SQLIRequestCollection import sqli_request_collection
from config import config
from general_functions import is_sql_syntax_error, is_sql_syntax_error_lists, send_HTTP_request, check_SQL_output, randomword

logger = config.logger
stats = config.stats
stats['total_req'] = 0 ## TOTAL requests captured by MITM proxy
stats['sql_req'] = 0 ## From total_req, we calculate TOTAL requests triggering SQL queries
stats['null_req'] = 0 ## From total_req, we calculate TOTAL requests bringing null parameter values
stats['not_sql_req'] = 0 ## From total_req, we calculate TOTAL requests NOT triggering SQL queries
stats['sql_injection_detected'] = 0 ## From sql_req, we calculate TOTAL requests confirmed as SQL Injection
stats['another_sql_error_detected'] = 0 ## From sql_req, we calculate TOTAL requests triggering SQL errors but not matched SQL strings
stats['sql_req_not_detected'] = 0 ## From sql_req, we calculate TOTAL requests NOT confirmed as SQL Injection
stats['error_req'] = 0

stats['fuzzed_req'] = 0
stats['processing_time_total'] = 0.0
stats['processing_time_ave'] = 0.0
stats['running_time'] = "Not finished yet"

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

async def fuzz(req_entry, req):
    logger.info(f"[SQLiFuzz {req_entry['sid']}] Calling send_requests for: %s", req_entry["request"]["url"])
    await send_requests(req_entry, req)

async def send_requests(req_entry, req):
    page = None
    WUT_URL = os.environ.get('WUT_URL', "http://localhost:8081")

    # Debug: log captured raw request vs converted request for comparison
    try:
        captured_body = req_entry.get('request', {}).get('body')
        captured_headers = req_entry.get('request', {}).get('headers')
        logger.info(f"[SQLiFuzz {req.id[-3:]}] DEBUG Captured request body (truncated): %s", str(captured_body)[:1000])
        logger.info(f"[SQLiFuzz {req.id[-3:]}] DEBUG Captured request headers: %s", captured_headers)
        logger.info(f"[SQLiFuzz {req.id[-3:]}] DEBUG Converted request.post_data_encoded (truncated): %s", str(req.post_data_encoded)[:1000])
        logger.info(f"[SQLiFuzz {req.id[-3:]}] DEBUG Converted request.header: %s", str(req.header))
        logger.info(f"[SQLiFuzz {req.id[-3:]}] DEBUG Converted request.content_type: %s", req.content_type)
    except Exception:
        pass

    async with async_playwright() as p:
        # Create a new API request context
        request_context = await p.request.new_context(
            base_url=WUT_URL
        )

        # request_result = await check_SQLI(page, req, request_context)
        request_result = await test_SQLi(page, req, request_context)
        

async def check_SQLI(page, req, request_context=None):
    logger.info(f"[SQLiFuzz {req.id[-3:]}] check_SQLI for {req}")
    prepared_target_request = None
    random_char = "'"
    chosen_pvs_idx = 0
    for x in range(70):
        chosen_req = req

        prepared_target_request = copy.deepcopy(chosen_req)
        prepared_target_request.parent = chosen_req
        prepared_target_request.update_id()

        logger.info(f"[SQLiFuzz {req.id[-3:]}] Getting prepared_target_request with ID {prepared_target_request.id[-3:]} for fuzzing iteration {x+1}/70")

        num_params = len(prepared_target_request.paramvals)
        if num_params==0:
            logger.info(f"[SQLiFuzz {req.id[-3:]}] check_SQLI is cancelled because num paramvals ==0")
            return False

        chosen_idx = 0
        if num_params>1:
            chosen_idx = random.randint(0,num_params-1)
        logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] chosen_idx: {chosen_idx} from {num_params}")


        chosen_pv = prepared_target_request.paramvals[chosen_idx]
        if random_char:
            logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] Use ' as the first weird char")

            matched_paramval = prepared_target_request.get_matched_paramval_from_found_values()
            if matched_paramval:
                chosen_pv = matched_paramval[chosen_pvs_idx]
                logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] Prioritize to fuzz matched SQL value first: {chosen_pv}")
                chosen_pv.value = chosen_pv.value+random_char
                if len(matched_paramval)>chosen_pvs_idx+1:
                    ## This means there are multiple matched SQL values and we need to fuzz them one by one
                    chosen_pvs_idx += 1
                elif random_char=="'":
                    random_char = "*"
                else:
                    random_char = None


            else:
                ## Prioritize the null value first
                null_paramvals = prepared_target_request.get_null_paramvals()
                if len(null_paramvals)>0:
                    chosen_pv = null_paramvals[len(null_paramvals)-1]
                    logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] Prioritize to fuzz null value first: {chosen_pv}")
                    chosen_pv.value = chosen_pv.value+randomword(5)+random_char
                    

                else:
                    chosen_pv.value = chosen_pv.value+random_char
                    if random_char=="'":
                        random_char = "*"
                    else:
                        random_char = None
        else:
            if chosen_pv.value==None:
                logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] chosen_pv.value is None, set it to randomword")
                chosen_pv.value = randomword(5)
            chosen_pv.value = str(chosen_pv.value)+random_weird_char()
        logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] Updated results: {chosen_pv}")
        prepared_target_request.update_param_from_paramvals()
        response = await send_HTTP_request(page, prepared_target_request, request_context)

        if response:
            response_str = await response.text()

            logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] Response status: {response.status}")
            logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] Response URL: {response.url}")
            logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] Was redirected: {response.url != prepared_target_request.full_url}")
            
            
        else:
            response_str = ""
        logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] Getting response: %s", response_str[0:400])

        result = check_SQL_output(prepared_target_request, chosen_pv.value)
        is_matched_without_syntax_error = False

        try:
            if prepared_target_request.SQL_injection_detected:
                stats['sql_injection_detected'] += 1
                logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] FOUND SQLi! SQL Injection is detected: {prepared_target_request} ==>  %s", prepared_target_request.SQL_injection_proof)
                print(f"[SQLiFuzz {prepared_target_request.id[-3:]}] FOUND SQLi! SQL Injection is detected: {prepared_target_request} ==>  %s", prepared_target_request.SQL_injection_proof)
                sqli_request_collection.add(prepared_target_request)
                sqli_request_collection.save_result()
                return prepared_target_request
            elif result:
                logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] Weird chars is detected: {prepared_target_request} --> {prepared_target_request.SQL_detected}")
                
                if prepared_target_request.SQL_detected and is_sql_syntax_error_lists(prepared_target_request):
                    stats['sql_injection_detected'] += 1
                    logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] SQL Injection is detected: {prepared_target_request} ==> {prepared_target_request.SQL_detected[0]}")
                    print(f"[SQLiFuzz {prepared_target_request.id[-3:]}] SQL Injection is detected: {prepared_target_request}")
                    prepared_target_request.SQL_injection_detected = True
                    sqli_request_collection.add(prepared_target_request)
                    sqli_request_collection.save_result()
                    return prepared_target_request
                elif prepared_target_request.SQL_detected and "*#*#error" in prepared_target_request.SQL_detected[0].lower():
                    is_matched_without_syntax_error = True
                    logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] However, we found another SQL Error: {prepared_target_request} --> {prepared_target_request.SQL_detected}")
                    is_saved = sqli_request_collection.add_to_different_error(prepared_target_request)
                    if is_saved:
                        print(f"We found another SQL Error: {prepared_target_request} --> {prepared_target_request.SQL_detected}")
                        sqli_request_collection.save_result()
                else:
                    logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] However, we don't find SQL Syntax Error: {prepared_target_request} --> {prepared_target_request.SQL_detected}")
                    is_matched_without_syntax_error = True
                    sqli_request_collection.add_to_matched_without_error(prepared_target_request)
            else:
                logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] No weird chars exist: {prepared_target_request}")
        except Exception as e:
            logger.error(f"[SQLiFuzz {prepared_target_request.id[-3:]}] Error checking SQL output: %s", e)

        if not is_matched_without_syntax_error and prepared_target_request.error_SQL_detected:
            if not req.another_sql_error_detected:
                stats['another_sql_error_detected'] += 1
                req.another_sql_error_detected=True
            logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] Unmatched SQL Error is detected: {prepared_target_request} ==> {prepared_target_request.error_SQL_detected}")
            sqli_request_collection.add(prepared_target_request)
            sqli_request_collection.save_result()

    logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] No SQL Injection. Drop it. {prepared_target_request}")
    stats['sql_req_not_detected'] += 1

async def test_SQLi(page, req, request_context=None):
    logger.info(f"[SQLiFuzz {req.id[-3:]}] test_SQLi for {req}")
    prepared_target_request = None
    chosen_pvs_idx = 0

    def get_mutation_strategy(iteration):
        # 0-2: apostrophe
        # 3-5: star
        # 6+: random char (excluding ' and *)
        
        if iteration == 0:
            return "'", "drop"
        elif iteration == 1:
            return "'", "tail"
        elif iteration == 2:
            return "'", "front"
        elif iteration == 3:
            return "*", "drop"
        elif iteration == 4:
            return "*", "tail"
        elif iteration == 5:
            return "*", "front"
        else:
            weird_chars = [
                '%', '&', '@', '#', '$', '!', '?', '~', '^',
                '(', ')', '[', ']', '{', '}', '<', '>', '|', '\\',
                '/', '+', '=', '-', '_', ':', ';', '"', ',',
                '.', '`'
            ]
            return random.choice(weird_chars), random.choice(["drop", "tail", "front", "random"])

    def mutate_value(original_value, injected_char, strategy):
        old_value = "" if original_value is None else str(original_value)

        if strategy == "drop":
            return injected_char
        elif strategy == "tail":
            return old_value + injected_char
        elif strategy == "front":
            return injected_char + old_value
        else: # random position
            insert_pos = random.randint(0, len(old_value))
            return old_value[:insert_pos] + injected_char + old_value[insert_pos:]

    for x in range(70):
        chosen_req = req

        prepared_target_request = copy.deepcopy(chosen_req)
        prepared_target_request.parent = chosen_req
        prepared_target_request.update_id()

        logger.info(f"[SQLiFuzz {req.id[-3:]}] Getting prepared_target_request with ID {prepared_target_request.id[-3:]} for test_SQLi iteration {x+1}/70")

        num_params = len(prepared_target_request.paramvals)
        if num_params == 0:
            logger.info(f"[SQLiFuzz {req.id[-3:]}] test_SQLi is cancelled because num paramvals ==0")
            return False

        chosen_idx = 0
        if num_params > 1:
            chosen_idx = random.randint(0, num_params - 1)
        logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] chosen_idx: {chosen_idx} from {num_params}")

        chosen_pv = prepared_target_request.paramvals[chosen_idx]

        matched_paramval = prepared_target_request.get_matched_paramval_from_found_values()
        if matched_paramval:
            if chosen_pvs_idx >= len(matched_paramval):
                chosen_pvs_idx = 0
            chosen_pv = matched_paramval[chosen_pvs_idx]
            logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] Prioritize to fuzz matched SQL value first: {chosen_pv}")
            if len(matched_paramval) > chosen_pvs_idx + 1:
                chosen_pvs_idx += 1
        else:
            null_paramvals = prepared_target_request.get_null_paramvals()
            if len(null_paramvals) > 0:
                chosen_pv = null_paramvals[len(null_paramvals) - 1]
                logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] Prioritize to fuzz null value first: {chosen_pv}")

        injected_char, strategy = get_mutation_strategy(x)
        old_value = chosen_pv.value
        chosen_pv.value = mutate_value(chosen_pv.value, injected_char, strategy)
        logger.info(
            f"[SQLiFuzz {prepared_target_request.id[-3:]}] Mutation applied. old='{old_value}' char='{injected_char}' strategy='{strategy}' new='{chosen_pv.value}'"
        )

        prepared_target_request.update_param_from_paramvals()

        response = await send_HTTP_request(page, prepared_target_request, request_context)

        if response:
            response_str = await response.text()

            logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] Response status: {response.status}")
            logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] Response URL: {response.url}")
            logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] Was redirected: {response.url != prepared_target_request.full_url}")
        else:
            response_str = ""
        logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] Getting response: %s", response_str[0:400])

        result = check_SQL_output(prepared_target_request, chosen_pv.value)
        is_matched_without_syntax_error = False

        try:
            if prepared_target_request.SQL_injection_detected:
                stats['sql_injection_detected'] += 1
                logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] FOUND SQLi! SQL Injection is detected: {prepared_target_request} ==>  %s", prepared_target_request.SQL_injection_proof)
                print(f"[SQLiFuzz {prepared_target_request.id[-3:]}] FOUND SQLi! SQL Injection is detected: {prepared_target_request} ==>  %s", prepared_target_request.SQL_injection_proof)
                sqli_request_collection.add(prepared_target_request)
                sqli_request_collection.save_result()
                return prepared_target_request
            elif result:
                logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] Weird chars is detected: {prepared_target_request} --> {prepared_target_request.SQL_detected}")

                if prepared_target_request.SQL_detected and is_sql_syntax_error_lists(prepared_target_request):
                    stats['sql_injection_detected'] += 1
                    logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] SQL Injection is detected: {prepared_target_request} ==> {prepared_target_request.SQL_detected[0]}")
                    print(f"[SQLiFuzz {prepared_target_request.id[-3:]}] SQL Injection is detected: {prepared_target_request}")
                    prepared_target_request.SQL_injection_detected = True
                    sqli_request_collection.add(prepared_target_request)
                    sqli_request_collection.save_result()
                    return prepared_target_request
                elif prepared_target_request.SQL_detected and "*#*#error" in prepared_target_request.SQL_detected[0].lower():
                    is_matched_without_syntax_error = True
                    logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] However, we found another SQL Error: {prepared_target_request} --> {prepared_target_request.SQL_detected}")
                    is_saved = sqli_request_collection.add_to_different_error(prepared_target_request)
                    if is_saved:
                        print(f"We found another SQL Error: {prepared_target_request} --> {prepared_target_request.SQL_detected}")
                        sqli_request_collection.save_result()
                else:
                    logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] However, we don't find SQL Syntax Error: {prepared_target_request} --> {prepared_target_request.SQL_detected}")
                    is_matched_without_syntax_error = True
                    sqli_request_collection.add_to_matched_without_error(prepared_target_request)
            else:
                logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] No weird chars exist: {prepared_target_request}")
        except Exception as e:
            logger.error(f"[SQLiFuzz {prepared_target_request.id[-3:]}] Error checking SQL output: %s", e)

        if not is_matched_without_syntax_error and prepared_target_request.error_SQL_detected:
            if not req.another_sql_error_detected:
                stats['another_sql_error_detected'] += 1
                req.another_sql_error_detected = True
            logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] Unmatched SQL Error is detected: {prepared_target_request} ==> {prepared_target_request.error_SQL_detected}")
            sqli_request_collection.add(prepared_target_request)
            sqli_request_collection.save_result()

    logger.info(f"[SQLiFuzz {prepared_target_request.id[-3:]}] No SQL Injection. Drop it. {prepared_target_request}")
    stats['sql_req_not_detected'] += 1
